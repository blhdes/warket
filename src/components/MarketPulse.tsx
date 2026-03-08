import { useEffect, useRef } from 'react'

/**
 * MarketPulse — infinite scrolling market-movement canvas.
 *
 * Theme-aware: electric green on dark, deep teal on light.
 * Columns physically scroll left-to-right like a live ticker tape.
 * A ring buffer of column state recycles seamlessly.
 */

const CHARS = '$%0123456789↑↓+−.·∞Δ'
const FONT_SIZE = 13
const COL_WIDTH = 20
const MAX_EMBERS = 40
const SCROLL_PX_PER_SEC = 14
const CSS_BLUR = 1
const TARGET_FPS = 24
const FRAME_INTERVAL = 1000 / TARGET_FPS

const PHI = 1.6180339887
const SQRT2 = 1.4142135624
const SQRT5 = 2.2360679775

/* ── Theme palettes ─────────────────────────────────────── */

interface Palette {
  peak: string            // brightest character color
  peakR: number; peakG: number; peakB: number  // RGB for alpha variants
  midR: number; midG: number; midB: number     // mid-body RGB
  baseR: number; baseG: number; baseB: number  // base/ember RGB
  bloomPeak: string       // bloom gradient stop at high price
  bloomLow: string        // bloom gradient stop at low price
  glowAlphaScale: number  // multiplier for shadowBlur intensity
  charAlphaBoost: number  // multiplier to lift character opacity (higher in light mode)
}

const DARK_PALETTE: Palette = {
  peak: '#39ff14',
  peakR: 57, peakG: 255, peakB: 20,
  midR: 45, midG: 210, midB: 90,
  baseR: 42, baseG: 157, baseB: 143,
  bloomPeak: 'rgba(57, 255, 20,',
  bloomLow: 'rgba(42, 157, 143,',
  glowAlphaScale: 1,
  charAlphaBoost: 1,
}

const LIGHT_PALETTE: Palette = {
  peak: '#0e8c7a',
  peakR: 14, peakG: 140, peakB: 122,
  midR: 20, midG: 120, midB: 108,
  baseR: 26, baseG: 131, baseB: 119,
  bloomPeak: 'rgba(14, 140, 122,',
  bloomLow: 'rgba(26, 131, 119,',
  glowAlphaScale: 0.85,
  charAlphaBoost: 2.2,
}

function getTheme(): 'dark' | 'light' {
  return document.documentElement.getAttribute('data-theme') === 'light' ? 'light' : 'dark'
}

/* ── Helpers ────────────────────────────────────────────── */

function randomChar() {
  return CHARS[Math.floor(Math.random() * CHARS.length)]
}

function noise(x: number, t: number, seed: number, drift: number): number {
  const s = seed + drift
  return (
    Math.sin(x * 0.07 + t * 0.47 * PHI + s) * 0.31 +
    Math.sin(x * 0.13 * SQRT2 + t * 0.83 + s * 2.3) * 0.27 +
    Math.sin(x * 0.31 * PHI + t * 1.7 + s * 4.1) * 0.23 +
    Math.sin(x * 0.52 + t * 2.3 * SQRT5 + s * 5.9) * 0.19
  )
}

function colorAtNorm(norm: number, intensity: number, p: Palette): string {
  const m = 0.6 + intensity * 0.4
  const b = p.charAlphaBoost
  if (norm > 0.88) return p.peak
  if (norm > 0.72) {
    const a = Math.min(1, (0.3 + (norm - 0.72) * 2.5) * m * b)
    return `rgba(${p.peakR}, ${p.peakG}, ${p.peakB}, ${a})`
  }
  if (norm > 0.45) {
    const a = Math.min(1, (0.12 + (norm - 0.45) * 0.7) * m * b)
    return `rgba(${p.midR}, ${p.midG}, ${p.midB}, ${a})`
  }
  if (norm > 0.2) {
    const a = Math.min(1, (0.06 + (norm - 0.2) * 0.35) * m * b)
    return `rgba(${p.baseR}, ${p.baseG}, ${p.baseB}, ${a})`
  }
  const a = Math.min(1, (0.02 + norm * 0.2) * m * b)
  return `rgba(${p.baseR}, ${p.baseG}, ${p.baseB}, ${a})`
}

/* ── Types ──────────────────────────────────────────────── */

interface Column {
  chars: string[]
  seed: number
  seedDrift: number
  driftSpeed: number
  spikeOffset: number
  spikeDecay: number
  smoothHeight: number
  reactSpeed: number
  prevHeight: number
  virtualIdx: number
}

interface EmberObj {
  x: number; y: number
  vx: number; vy: number
  char: string
  life: number; maxLife: number
  size: number
  kind: 'spark' | 'float' | 'streak'
}

interface Mood {
  volatility: number; trend: number; activity: number
  targetVolatility: number; targetTrend: number; targetActivity: number
}

function createColumn(maxRows: number, virtualIdx: number): Column {
  return {
    chars: Array.from({ length: maxRows }, randomChar),
    seed: Math.random() * 1000,
    seedDrift: 0,
    driftSpeed: 0.01 + Math.random() * 0.04,
    spikeOffset: 0, spikeDecay: 0,
    smoothHeight: 0,
    reactSpeed: 3 + Math.random() * 6,
    prevHeight: 0,
    virtualIdx,
  }
}

/* ── Component ──────────────────────────────────────────── */

export default function MarketPulse({ opacity = 0.5 }: { opacity?: number }) {
  const canvasRef = useRef<HTMLCanvasElement>(null)

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return
    const ctx = canvas.getContext('2d')
    if (!ctx) return

    let animId: number
    let columns: Column[] = []
    let embers: EmberObj[] = []
    let screenCols = 0
    let bufferCols = 0
    let maxRows = 0
    let palette: Palette = getTheme() === 'light' ? LIGHT_PALETTE : DARK_PALETTE

    const waves: { phase: number; amp: number; speed: number; decay: number }[] = []
    const mood: Mood = {
      volatility: 0.5, trend: 0, activity: 0.5,
      targetVolatility: 0.5, targetTrend: 0, targetActivity: 0.5,
    }

    let scrollPx = 0
    let lastBaseIdx = 0
    let nextVirtualIdx = 0
    let lastResizeW = 0
    let lastResizeH = 0

    // Watch for theme changes
    const observer = new MutationObserver(() => {
      palette = getTheme() === 'light' ? LIGHT_PALETTE : DARK_PALETTE
    })
    observer.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ['data-theme'],
    })

    function resize() {
      const w = canvas!.offsetWidth
      const h = canvas!.offsetHeight
      if (w === lastResizeW && h === lastResizeH) return
      lastResizeW = w
      lastResizeH = h

      const dpr = window.devicePixelRatio || 1
      canvas!.width = w * dpr
      canvas!.height = h * dpr
      ctx!.setTransform(dpr, 0, 0, dpr, 0, 0)

      screenCols = Math.floor(w / COL_WIDTH)
      bufferCols = screenCols + 2
      maxRows = Math.floor(h / FONT_SIZE)

      if (columns.length === 0) {
        nextVirtualIdx = 0
        for (let j = 0; j < bufferCols; j++) {
          columns.push(createColumn(maxRows, nextVirtualIdx++))
        }
      } else {
        while (columns.length < bufferCols) columns.push(createColumn(maxRows, nextVirtualIdx++))
        if (columns.length > bufferCols) columns.length = bufferCols
      }
      for (const col of columns) {
        while (col.chars.length < maxRows) col.chars.push(randomChar())
      }
    }

    resize()
    window.addEventListener('resize', resize)

    let prev = performance.now()

    // Pause animation when the tab is not visible
    function handleVisibility() {
      if (document.hidden) {
        cancelAnimationFrame(animId)
      } else {
        prev = performance.now()
        animId = requestAnimationFrame(draw)
      }
    }
    document.addEventListener('visibilitychange', handleVisibility)

    function spawnEmber(x: number, y: number, kind: EmberObj['kind'] = 'spark') {
      if (embers.length >= MAX_EMBERS) return
      const maxLife = kind === 'streak' ? 0.3 + Math.random() * 0.5
        : kind === 'float' ? 1.5 + Math.random() * 2.5
        : 0.6 + Math.random() * 1.5
      embers.push({
        x, y,
        vx: kind === 'streak' ? (Math.random() - 0.5) * 60 : (Math.random() - 0.5) * 20,
        vy: kind === 'float' ? -(8 + Math.random() * 15) : -(20 + Math.random() * 40),
        char: randomChar(), life: maxLife, maxLife,
        size: FONT_SIZE * (kind === 'streak' ? 0.4 + Math.random() * 0.3 : 0.5 + Math.random() * 0.5),
        kind,
      })
    }

    function draw(now: number) {
      animId = requestAnimationFrame(draw)
      const elapsed = now - prev
      if (elapsed < FRAME_INTERVAL) return
      const dt = Math.min(elapsed / 1000, 0.05)
      prev = now
      const t = now / 1000
      const p = palette

      const w = canvas!.offsetWidth
      const h = canvas!.offsetHeight

      ctx!.clearRect(0, 0, w, h)

      // ── Mood ───────────────────────────────────────────────
      if (Math.random() < dt * 0.08) {
        mood.targetVolatility = 0.15 + Math.random() * 0.85
        mood.targetTrend = (Math.random() - 0.5) * 0.5
        mood.targetActivity = 0.2 + Math.random() * 0.8
      }
      const moodLerp = 1 - Math.pow(0.3, dt)
      mood.volatility += (mood.targetVolatility - mood.volatility) * moodLerp
      mood.trend += (mood.targetTrend - mood.trend) * moodLerp
      mood.activity += (mood.targetActivity - mood.activity) * moodLerp

      // ── Waves ──────────────────────────────────────────────
      if (Math.random() < dt * (0.3 + mood.volatility * 0.5)) {
        waves.push({
          phase: Math.random() * Math.PI * 2,
          amp: (0.08 + Math.random() * 0.2) * mood.volatility,
          speed: 1.5 + Math.random() * 4,
          decay: 0.3 + Math.random() * 0.8,
        })
      }
      for (let w2 = waves.length - 1; w2 >= 0; w2--) {
        waves[w2].amp *= Math.max(0, 1 - waves[w2].decay * dt)
        if (waves[w2].amp < 0.003) waves.splice(w2, 1)
      }

      // ── Scroll ─────────────────────────────────────────────
      const prevScrollPx = scrollPx
      scrollPx += SCROLL_PX_PER_SEC * dt
      const frameDriftPx = scrollPx - prevScrollPx
      const baseIdx = Math.floor(scrollPx / COL_WIDTH)
      const fracPx = scrollPx % COL_WIDTH

      const shifted = baseIdx - lastBaseIdx
      if (shifted > 0) {
        const n = Math.min(shifted, bufferCols)
        for (let s = 0; s < n; s++) {
          columns.shift()
          columns.push(createColumn(maxRows, nextVirtualIdx++))
        }
      }
      lastBaseIdx = baseIdx

      for (const ember of embers) ember.x -= frameDriftPx

      // ── Columns ────────────────────────────────────────────
      ctx!.font = `${FONT_SIZE}px JetBrains Mono, monospace`
      ctx!.textAlign = 'center'
      const chartRows = Math.floor(maxRows * 0.72)

      for (let j = 0; j < columns.length; j++) {
        const col = columns[j]
        const x = j * COL_WIDTH + COL_WIDTH / 2 - fracPx
        if (x < -COL_WIDTH * 2 || x > w + COL_WIDTH * 2) continue

        col.seedDrift += col.driftSpeed * dt
        const raw = noise(col.virtualIdx, t, col.seed, col.seedDrift)
        let price = (raw + 1) / 2 + mood.trend * 0.3

        col.spikeOffset *= Math.max(0, 1 - col.spikeDecay * dt)
        if (Math.abs(col.spikeOffset) < 0.003) col.spikeOffset = 0
        if (Math.random() < dt * (2 + mood.volatility * 8)) {
          col.spikeOffset += (Math.random() - 0.4) * 0.45 * mood.volatility
          col.spikeDecay = 1 + Math.random() * 3
        }

        let waveSum = 0
        for (const wave of waves) {
          waveSum += wave.amp * Math.sin(wave.phase + col.virtualIdx * 0.12 - t * wave.speed)
        }

        price = Math.max(0.01, Math.min(1, price + col.spikeOffset + waveSum))
        const targetHeight = price * chartRows
        col.smoothHeight += (targetHeight - col.smoothHeight) * (1 - Math.pow(0.5, col.reactSpeed * dt))

        const filledRows = Math.max(1, Math.round(col.smoothHeight))
        const fractional = col.smoothHeight - Math.floor(col.smoothHeight)
        const peakY = (maxRows - col.smoothHeight) * FONT_SIZE

        // Characters
        const intensity = 0.5 + mood.volatility * 0.5
        for (let r = 0; r < filledRows; r++) {
          const row = maxRows - 1 - r
          if (row < 0) break
          const py = row * FONT_SIZE + FONT_SIZE
          const norm = col.smoothHeight > 1 ? r / (col.smoothHeight - 1) : 1

          const isTopRow = r === filledRows - 1
          const alphaMultiplier = isTopRow ? 0.4 + fractional * 0.6 : 1

          if (Math.random() < 0.01 + mood.volatility * 0.03) col.chars[row] = randomChar()

          // Ghosts
          if (isTopRow && Math.random() < 0.25 + mood.activity * 0.2) {
            const gc = 1 + Math.floor(Math.random() * 3)
            for (let g = 0; g < gc; g++) {
              const gr = row - 1 - Math.floor(Math.random() * 4)
              if (gr >= 0) {
                ctx!.shadowBlur = 0
                ctx!.fillStyle = `rgba(${p.peakR}, ${p.peakG}, ${p.peakB}, ${Math.min(1, (0.03 + Math.random() * 0.08) * mood.activity * p.charAlphaBoost)})`
                ctx!.fillText(randomChar(), x, gr * FONT_SIZE + FONT_SIZE)
              }
            }
          }

          if (norm > 0.88) {
            ctx!.shadowColor = p.peak
            ctx!.shadowBlur = (12 + mood.volatility * 6) * p.glowAlphaScale
            ctx!.globalAlpha = alphaMultiplier
            ctx!.fillStyle = p.peak
          } else {
            ctx!.shadowBlur = 0
            ctx!.globalAlpha = norm > 0.7 ? alphaMultiplier : 1
            ctx!.fillStyle = colorAtNorm(norm, intensity, p)
          }

          ctx!.fillText(col.chars[row], x, py)
        }

        ctx!.shadowBlur = 0
        ctx!.globalAlpha = 1

        // Embers
        const hd = col.smoothHeight - col.prevHeight
        if (hd > 0.5 && Math.random() < mood.activity * 0.5) spawnEmber(x, peakY, 'spark')
        if (col.smoothHeight > chartRows * 0.35 && Math.random() < dt * mood.activity * 1.5) {
          spawnEmber(x + (Math.random() - 0.5) * COL_WIDTH * 1.5, peakY + Math.random() * FONT_SIZE * 3, 'float')
        }
        if (Math.abs(hd) > 2 && Math.random() < 0.3 * mood.volatility) spawnEmber(x, peakY, 'streak')
        col.prevHeight = col.smoothHeight
      }

      // ── Embers ─────────────────────────────────────────────
      for (let e = embers.length - 1; e >= 0; e--) {
        const ember = embers[e]
        ember.life -= dt
        if (ember.life <= 0 || ember.x < -50 || ember.x > w + 50) { embers.splice(e, 1); continue }

        ember.x += ember.vx * dt
        ember.y += ember.vy * dt

        if (ember.kind === 'float') {
          ember.vy *= 0.995
          ember.vx += Math.sin(t * 3 + ember.x * 0.05) * 8 * dt
        } else if (ember.kind === 'streak') {
          ember.vy *= 0.96; ember.vx *= 0.97
        } else {
          ember.vy *= 0.98
          ember.vx += (Math.random() - 0.5) * 50 * dt
        }

        const ln = ember.life / ember.maxLife
        const alpha = Math.min(1, ln * ln * (ember.kind === 'float' ? 0.5 : 0.7) * p.charAlphaBoost)

        ctx!.font = `${ember.size}px JetBrains Mono, monospace`
        ctx!.fillStyle = `rgba(${p.peakR}, ${p.peakG}, ${p.peakB}, ${alpha})`
        ctx!.fillText(ember.char, ember.x, ember.y)

        if (Math.random() < 0.04) ember.char = randomChar()
      }

      ctx!.shadowBlur = 0

      // ── Horizon bloom ──────────────────────────────────────
      const ha = 0.06 + mood.activity * 0.08
      const hg = ctx!.createLinearGradient(0, h, 0, h - h * 0.2)
      hg.addColorStop(0, `rgba(${p.peakR}, ${p.peakG}, ${p.peakB}, ${ha})`)
      hg.addColorStop(1, `rgba(${p.peakR}, ${p.peakG}, ${p.peakB}, 0)`)
      ctx!.fillStyle = hg
      ctx!.fillRect(0, h - h * 0.2, w, h * 0.2)
    }

    animId = requestAnimationFrame(draw)

    return () => {
      cancelAnimationFrame(animId)
      window.removeEventListener('resize', resize)
      document.removeEventListener('visibilitychange', handleVisibility)
      observer.disconnect()
    }
  }, [])

  return (
    <canvas
      ref={canvasRef}
      style={{
        position: 'absolute',
        inset: 0,
        width: '100%',
        height: '100%',
        opacity,
        filter: `blur(${CSS_BLUR}px)`,
        pointerEvents: 'none',
      }}
    />
  )
}

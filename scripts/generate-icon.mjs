import sharp from 'sharp'
import { join, dirname } from 'path'
import { fileURLToPath } from 'url'

const __dirname = dirname(fileURLToPath(import.meta.url))

const SIZE = 1024
const BG = '#08090d'
const STROKE = '#2a9d8f'

// The Logo.tsx SVG path scaled from 64x64 viewBox to 1024x1024
// Scale factor: 1024/64 = 16, but we want padding so use ~12x with centering
const SCALE = 12
const OFFSET_X = (SIZE - 64 * SCALE) / 2
const OFFSET_Y = (SIZE - 64 * SCALE) / 2

const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${SIZE}" height="${SIZE}" viewBox="0 0 ${SIZE} ${SIZE}">
  <rect width="${SIZE}" height="${SIZE}" rx="224" fill="${BG}"/>
  <g transform="translate(${OFFSET_X}, ${OFFSET_Y}) scale(${SCALE})">
    <path
      d="M 4,16 L 16,50 L 32,24 L 48,50 L 60,8"
      stroke="${STROKE}"
      stroke-width="5"
      stroke-linecap="round"
      stroke-linejoin="round"
      fill="none"
    />
  </g>
</svg>`

const outPath = join(__dirname, '..', 'ios', 'App', 'App', 'Assets.xcassets', 'AppIcon.appiconset', 'AppIcon-512@2x.png')

await sharp(Buffer.from(svg)).png().toFile(outPath)
console.log(`Icon generated: ${outPath}`)

import { describe, it, expect } from 'vitest'
import { renderMarkdown } from '@src/lib/markdown'

describe('renderMarkdown – strips dangerous content', () => {
  it('removes event handlers from raw HTML', () => {
    const html = renderMarkdown('<img src=x onerror="alert(1)">')
    expect(html).not.toContain('onerror')
  })

  it('removes javascript: links', () => {
    const html = renderMarkdown('[x](javascript:alert(1))')
    expect(html).not.toContain('javascript:')
  })

  it('removes script tags', () => {
    const html = renderMarkdown('<script>alert(1)</script>')
    expect(html).not.toContain('<script')
  })
})

describe('renderMarkdown – keeps normal formatting', () => {
  it('turns **bold** into <strong>', () => {
    expect(renderMarkdown('**bold**')).toContain('<strong>bold</strong>')
  })

  it('makes links open in a new tab without opener or referrer', () => {
    const html = renderMarkdown('[site](https://example.com)')
    expect(html).toContain('href="https://example.com"')
    expect(html).toContain('target="_blank"')
    expect(html).toContain('rel="noopener noreferrer"')
  })
})

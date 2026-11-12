import DOMPurify from 'dompurify'
import { marked } from 'marked'

marked.setOptions({ breaks: true, gfm: true })

// Links written in notes always open in a new tab and never hand over the opener or referrer.
DOMPurify.addHook('afterSanitizeAttributes', node => {
  if (node.tagName !== 'A') return
  node.setAttribute('target', '_blank')
  node.setAttribute('rel', 'noopener noreferrer')
})

/** Markdown to HTML that is safe to inject: no scripts, no event handlers, no javascript: links. */
export function renderMarkdown(source: string): string {
  const rawHtml = marked.parse(source, { async: false })
  return DOMPurify.sanitize(rawHtml, {
    USE_PROFILES: { html: true },
    FORBID_TAGS: ['style', 'form', 'input', 'button', 'textarea', 'select'],
  })
}

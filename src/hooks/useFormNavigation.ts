import { useEffect, type RefObject } from 'react'

/**
 * Wires up iOS-style keyboard navigation for forms:
 * - Enter on an <input> advances focus to the next visible input/textarea
 * - Enter on the last field clicks the primary submit button
 * - Sets `enterKeyHint` to "next" or "done" so iOS renders the correct key label
 * - Scrolls the newly focused field into view
 *
 * Textareas are *not* intercepted (Enter inserts a newline) but they are
 * included in the tab order so "next" from a preceding input can land on them.
 */
export function useFormNavigation(formRef: RefObject<HTMLFormElement | null>) {
  useEffect(() => {
    const form = formRef.current
    if (!form) return

    const isField = (el: Element): el is HTMLInputElement | HTMLTextAreaElement => {
      if (el.tagName === 'TEXTAREA') return true
      if (el.tagName === 'INPUT') {
        const t = (el as HTMLInputElement).type
        return t !== 'checkbox' && t !== 'hidden' && t !== 'radio'
      }
      return false
    }

    const visibleFields = () =>
      Array.from(form.elements)
        .filter(isField)
        .filter(el => el.offsetParent !== null)

    const submitBtn = () =>
      form.querySelector<HTMLButtonElement>('button[type="submit"]')

    const updateHints = () => {
      const fields = visibleFields()
      fields.forEach((field, i) => {
        if (field.tagName === 'TEXTAREA') return
        field.setAttribute('enterkeyhint', i < fields.length - 1 ? 'next' : 'done')
      })
    }

    const handleKeyDown = (e: Event) => {
      const ke = e as KeyboardEvent
      if (ke.key !== 'Enter') return

      const target = ke.target as HTMLElement
      if (target.tagName === 'TEXTAREA') return
      if (target.tagName !== 'INPUT') return

      const fields = visibleFields()
      const idx = fields.indexOf(target as HTMLInputElement)
      if (idx === -1) return

      ke.preventDefault()

      if (idx < fields.length - 1) {
        const next = fields[idx + 1]
        next.focus()
        next.scrollIntoView({ block: 'nearest', behavior: 'smooth' })
      } else {
        const btn = submitBtn()
        if (btn) btn.click()
      }
    }

    updateHints()
    form.addEventListener('keydown', handleKeyDown)

    const observer = new MutationObserver(updateHints)
    observer.observe(form, { childList: true, subtree: true })

    return () => {
      form.removeEventListener('keydown', handleKeyDown)
      observer.disconnect()
    }
  }, [formRef])
}

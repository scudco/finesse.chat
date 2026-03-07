import { Controller } from "@hotwired/stimulus"

const currentUser = () => document.getElementById("current-username")?.textContent

export default class extends Controller {
  static targets = ["content", "editor", "actions", "textarea"]
  static values  = { author: String }

  connect() {
    if (this.authorValue !== currentUser()) {
      if (this.hasActionsTarget) this.actionsTarget.remove()
      if (this.hasEditorTarget) this.editorTarget.remove()
    }
  }

  startEdit() {
    this.contentTarget.classList.add("hidden")
    this.editorTarget.classList.remove("hidden")
    const ta = this.textareaTarget
    ta.focus()
    ta.setSelectionRange(ta.value.length, ta.value.length)
    this.element.scrollIntoView({ block: "nearest" })
  }

  cancelEdit() {
    this.textareaTarget.value = this.textareaTarget.defaultValue
    this.editorTarget.classList.add("hidden")
    this.contentTarget.classList.remove("hidden")
    this.#focusChatInput()
  }

  submitted() {
    this.#focusChatInput()
  }

  keydown(event) {
    if (event.key === "Escape") {
      this.cancelEdit()
    } else if ((event.metaKey || event.ctrlKey) && event.key === "Enter") {
      event.preventDefault()
      event.target.closest("form")?.requestSubmit()
    }
  }

  // private

  #focusChatInput() {
    document.querySelector('[data-chat-target="input"]')?.focus()
  }
}

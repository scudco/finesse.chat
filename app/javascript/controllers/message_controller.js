import { Controller } from "@hotwired/stimulus"

const currentUser = document.querySelector('meta[name="current-user"]')?.content

export default class extends Controller {
  static targets = ["content", "editor", "actions"]
  static values  = { author: String }

  connect() {
    if (this.authorValue !== currentUser) {
      if (this.hasActionsTarget) this.actionsTarget.remove()
      if (this.hasEditorTarget) this.editorTarget.remove()
    }
  }

  startEdit() {
    this.contentTarget.classList.add("hidden")
    this.editorTarget.classList.remove("hidden")
    const textarea = this.editorTarget.querySelector("textarea")
    textarea.focus()
    this.element.scrollIntoView({ block: "nearest" })
  }

  cancelEdit() {
    const textarea = this.editorTarget.querySelector("textarea")
    textarea.value = textarea.defaultValue
    this.editorTarget.classList.add("hidden")
    this.contentTarget.classList.remove("hidden")
  }

  keydown(event) {
    if (event.key === "Escape") {
      this.cancelEdit()
    } else if ((event.metaKey || event.ctrlKey) && event.key === "Enter") {
      event.target.closest("form").requestSubmit()
    }
  }
}

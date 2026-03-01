import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["scroll"]
  static values = { currentUser: String }

  connect() {
    this.scrollToBottom()
    this.markOwnMessages()
    this.observer = new MutationObserver(() => {
      this.scrollToBottom()
      this.markOwnMessages()
    })
    this.observer.observe(this.scrollTarget, { childList: true, subtree: true })
  }

  disconnect() {
    this.observer.disconnect()
  }

  scrollToBottom() {
    this.scrollTarget.scrollTop = this.scrollTarget.scrollHeight
  }

  markOwnMessages() {
    this.scrollTarget.querySelectorAll("[data-author]:not([data-own])").forEach(el => {
      if (el.dataset.author === this.currentUserValue) {
        el.dataset.own = "true"
      }
    })
  }
}
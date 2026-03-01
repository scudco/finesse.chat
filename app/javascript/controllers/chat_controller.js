import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["scroll", "messages", "jumpButton", "loadOlder"]
  static values  = { currentUser: String, olderUrl: String }

  connect() {
    this.atBottom     = true
    this.loadingOlder = false
    this.hasMore      = true
    this.scrollToBottom()
    requestAnimationFrame(() => this.scrollTarget.classList.remove("invisible"))
    this.markOwnMessages()
    this.observer = new MutationObserver(() => {
      this.markOwnMessages()
      if (this.atBottom) {
        this.trimOldMessages()
        this.scrollToBottom()
      } else {
        this.showJumpButton()
      }
    })
    this.observer.observe(this.scrollTarget, { childList: true, subtree: true })
  }

  disconnect() {
    this.observer.disconnect()
  }

  // Wired via data-action="scroll->chat#onScroll" on the scroll target.
  onScroll() {
    this.atBottom = this.isAtBottom()
    if (this.atBottom) this.hideJumpButton()
    this.maybeLoadOlder()
  }

  jumpToPresent() {
    this.scrollToBottom()
    this.hideJumpButton()
  }

  // private

  maybeLoadOlder() {
    if (!this.hasMore || this.loadingOlder) return
    if (this.scrollTarget.scrollTop < 200) this.loadOlderMessages()
  }

  async loadOlderMessages() {
    const beforeId = this.oldestMessageId
    if (!beforeId) return

    this.loadingOlder = true
    this.loadOlderTarget.classList.remove("hidden")

    const prevScrollHeight = this.scrollTarget.scrollHeight
    const prevScrollTop    = this.scrollTarget.scrollTop

    const url      = new URL(this.olderUrlValue, location.href)
    url.searchParams.set("before_id", beforeId)

    const response = await fetch(url, {
      headers: { Accept: "text/vnd.turbo-stream.html" }
    })

    if (response.ok) {
      const html = await response.text()
      if (html.trim() === "") {
        this.hasMore = false
      } else {
        await Turbo.renderStreamMessage(html)
        this.scrollTarget.scrollTop = prevScrollTop + (this.scrollTarget.scrollHeight - prevScrollHeight)
      }
    }

    this.loadOlderTarget.classList.add("hidden")
    this.loadingOlder = false
  }

  get oldestMessageId() {
    const first = this.messagesTarget.firstElementChild
    if (!first) return null
    const match = first.id.match(/\d+$/)
    return match ? parseInt(match[0]) : null
  }

  scrollToBottom() {
    this.scrollTarget.scrollTop = this.scrollTarget.scrollHeight
  }

  isAtBottom() {
    const el = this.scrollTarget
    return el.scrollHeight - el.scrollTop - el.clientHeight < 50
  }

  showJumpButton() {
    this.jumpButtonTarget.classList.remove("hidden")
  }

  hideJumpButton() {
    this.jumpButtonTarget.classList.add("hidden")
  }

  trimOldMessages() {
    while (this.messagesTarget.children.length > 100) {
      this.messagesTarget.firstElementChild.remove()
    }
  }

  markOwnMessages() {
    this.scrollTarget.querySelectorAll("[data-author]:not([data-own])").forEach(el => {
      if (el.dataset.author === this.currentUserValue) el.dataset.own = "true"
    })
  }
}
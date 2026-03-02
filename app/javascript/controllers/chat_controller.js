import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["scroll", "messages", "jumpButton", "loadOlder"]
  static values  = { currentUser: String, olderUrl: String }

  connect() {
    this.atBottom          = true
    this.loadingOlder      = false
    this.hasMore           = true
    this.scrollingToBottom = false
    this.scrollTarget.scrollTop = this.scrollTarget.scrollHeight
    requestAnimationFrame(() => this.scrollTarget.classList.remove("opacity-0"))
    this.observer = new MutationObserver(() => {
      if (this.atBottom || this.scrollingToBottom) {
        this.trimOldMessages()
        this.scrollToBottom()
      } else {
        this.showJumpButton()
      }
      this.insertDateSeparators()
    })
    this.observer.observe(this.scrollTarget, { childList: true, subtree: true })
    this.insertDateSeparators()
  }

  disconnect() {
    this.observer.disconnect()
  }

  // Wired via data-action="scroll->chat#onScroll" on the scroll target.
  onScroll() {
    this.atBottom = this.isAtBottom()
    if (this.atBottom) {
      this.scrollingToBottom = false
      this.hideJumpButton()
    } else if (!this.scrollingToBottom) {
      this.showJumpButton()
    }
    this.maybeLoadOlder()
  }

  jumpToPresent() {
    this.scrollToBottom()
    this.hideJumpButton()
  }

  submitOnEnter(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      event.target.closest("form").requestSubmit()
    }
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
    const first = [...this.messagesTarget.children].find(el => !el.dataset.dateSeparator)
    if (!first) return null
    const match = first.id.match(/\d+$/)
    return match ? parseInt(match[0]) : null
  }

  insertDateSeparators() {
    this.observer.disconnect()

    this.messagesTarget.querySelectorAll("[data-date-separator]").forEach(el => el.remove())

    let lastDateStr = null
    for (const child of this.messagesTarget.children) {
      const timeEl = child.querySelector("time[datetime]")
      if (!timeEl) continue

      const dt = new Date(timeEl.dateTime)
      const dateStr = dt.toDateString()
      if (dateStr !== lastDateStr) {
        child.before(this.buildDateSeparator(dt))
        lastDateStr = dateStr
      }
    }

    this.observer.observe(this.scrollTarget, { childList: true, subtree: true })
  }

  buildDateSeparator(dt) {
    const now = new Date()
    const yesterday = new Date(now)
    yesterday.setDate(yesterday.getDate() - 1)

    let label
    if (dt.toDateString() === now.toDateString()) {
      label = "Today"
    } else if (dt.toDateString() === yesterday.toDateString()) {
      label = "Yesterday"
    } else {
      label = dt.toLocaleDateString([], {
        weekday: "long", month: "long", day: "numeric",
        year: dt.getFullYear() === now.getFullYear() ? undefined : "numeric"
      })
    }

    const div = document.createElement("div")
    div.dataset.dateSeparator = "true"
    div.className = "text-center text-xs text-gray-400 py-2 select-none"
    div.textContent = label
    return div
  }

  scrollToBottom() {
    this.scrollingToBottom = true
    this.scrollTarget.scrollTo({ top: this.scrollTarget.scrollHeight, behavior: "smooth" })
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
    const messages = [...this.messagesTarget.children].filter(el => !el.dataset.dateSeparator)
    while (messages.length > 100) {
      const oldest = messages.shift()
      const prev = oldest.previousElementSibling
      if (prev?.dataset.dateSeparator) prev.remove()
      oldest.remove()
    }
  }
}

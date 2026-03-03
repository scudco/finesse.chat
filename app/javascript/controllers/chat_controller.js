import { Controller } from "@hotwired/stimulus"

const currentUser = document.querySelector('meta[name="current-user"]')?.content

// Reload when iOS Safari restores the page from bfcache — stale messages
// can't be patched by polling alone since pollForMessages only appends newer.
window.addEventListener('pageshow', (event) => {
  if (event.persisted) window.location.reload()
})

export default class extends Controller {
  static targets = ["scroll", "messages", "jumpButton", "loadOlder", "hint", "input"]
  static values  = { olderUrl: String, newerUrl: String }

  connect() {
    this.atBottom          = true
    this.loadingOlder      = false
    this.hasMore           = true
    this.scrollingToBottom = false
    this.scrollTarget.scrollTop = this.scrollTarget.scrollHeight
    requestAnimationFrame(() => this.scrollTarget.classList.remove("opacity-0"))
    this.polling = false
    this.pollInterval = setInterval(() => this.pollForMessages(), 20_000)
    this.handleVisibilityChange = () => { if (document.visibilityState === "visible") this.pollForMessages() }
    document.addEventListener("visibilitychange", this.handleVisibilityChange)
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
    this.handleBeforeStreamRender = this.deduplicateAppend.bind(this)
    document.addEventListener("turbo:before-stream-render", this.handleBeforeStreamRender)
  }

  disconnect() {
    clearInterval(this.pollInterval)
    document.removeEventListener("visibilitychange", this.handleVisibilityChange)
    this.observer.disconnect()
    document.removeEventListener("turbo:before-stream-render", this.handleBeforeStreamRender)
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
    this.scrollToBottom("smooth")
    this.hideJumpButton()
  }

  inputTargetConnected(el) {
    el.focus()
  }

  hintTargetConnected(el) {
    const isMac = /Mac|iPhone|iPad|iPod/.test(navigator.platform)
    el.textContent = (isMac ? "⌘" : "Ctrl") + "+Enter to send"
  }

  submitOnEnter(event) {
    if (event.key === "Enter" && (event.metaKey || event.ctrlKey)) {
      event.preventDefault()
      event.target.closest("form").requestSubmit()
    } else if (event.key === "ArrowUp" && event.target.value === "") {
      event.preventDefault()
      this.editLastOwnMessage()
    }
  }

  editLastOwnMessage() {
    const last = [...this.messagesTarget.querySelectorAll("[data-message-author-value]")]
      .findLast(el => el.dataset.messageAuthorValue === currentUser)
    if (!last) return
    this.application.getControllerForElementAndIdentifier(last, "message")?.startEdit()
  }

  deduplicateAppend(event) {
    const stream = event.detail.newStream
    if (stream.action !== "append" && stream.action !== "prepend") return
    if (stream.target !== this.messagesTarget.id) return

    const el = stream.templateContent?.firstElementChild
    if (!el?.id) return

    if (document.getElementById(el.id)) {
      event.detail.render = () => {}
      return
    }

    if (stream.action === "append") {
      const incomingId = this.#parseId(el.id)
      const lastId = this.latestMessageId
      if (incomingId && lastId && incomingId < lastId) {
        event.detail.render = () => {
          const messages = [...this.messagesTarget.children].filter(m => !m.dataset.dateSeparator && m.id)
          const anchor = messages.find(m => this.#parseId(m.id) > incomingId)
          anchor ? anchor.before(el) : this.messagesTarget.append(el)
        }
      }
    }
  }

  // private

  #parseId(id) {
    const match = id?.match(/\d+$/)
    return match ? parseInt(match[0]) : null
  }

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

    const url = new URL(this.olderUrlValue, location.href)
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

  async pollForMessages() {
    if (this.polling) return
    const afterId = this.latestMessageId
    if (!afterId) return

    this.polling = true

    const url = new URL(this.newerUrlValue, location.href)
    url.searchParams.set("after_id", afterId)

    const response = await fetch(url, { headers: { Accept: "text/vnd.turbo-stream.html" } })
    if (response.ok) {
      const html = await response.text()
      if (html.trim()) await Turbo.renderStreamMessage(html)
    }

    this.polling = false
  }

  get latestMessageId() {
    const last = [...this.messagesTarget.children].findLast(el => !el.dataset.dateSeparator)
    return this.#parseId(last?.id)
  }

  get oldestMessageId() {
    const first = [...this.messagesTarget.children].find(el => !el.dataset.dateSeparator)
    return this.#parseId(first?.id)
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

  scrollToBottom(behavior = "instant") {
    this.scrollingToBottom = true
    this.scrollTarget.scrollTo({ top: this.scrollTarget.scrollHeight, behavior })
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
    for (let i = 0; i < messages.length - 100; i++) {
      const prev = messages[i].previousElementSibling
      if (prev?.dataset.dateSeparator) prev.remove()
      messages[i].remove()
    }
  }
}

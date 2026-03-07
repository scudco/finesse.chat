import { Controller } from "@hotwired/stimulus"

const currentUser = () => document.getElementById("current-username")?.textContent


export default class extends Controller {
  static targets = ["scroll", "messages", "jumpButton", "loadOlder", "hint", "input", "pollBar", "transportButton"]
  static values  = { olderUrl: String, newerUrl: String, pollInterval: { type: Number, default: 20_000 }, transport: String }

  connect() {
    this.atBottom          = true
    this.loadingOlder      = false
    this.hasMore           = true
    this.scrollingToBottom = false
    requestAnimationFrame(() => this.scrollTarget.classList.remove("opacity-0"))
    this.scrollToBottom()
    this.polling = false
    this.#schedulePoll()
    this.handleVisibilityChange = () => { if (document.visibilityState === "visible") this.#fetchLatest() }
    this.handlePageShow = (e) => { if (e.persisted) this.#fetchLatest() }
    document.addEventListener("visibilitychange", this.handleVisibilityChange)
    window.addEventListener("pageshow", this.handlePageShow)
    this.observer = new MutationObserver(() => {
      if (this.atBottom || this.scrollingToBottom) {
        this.trimOldMessages()
        this.scrollToBottom()
      } else {
        this.showJumpButton()
      }
      clearTimeout(this.dateSepTimeout)
      this.dateSepTimeout = setTimeout(() => {
        this.insertDateSeparators()
        this.markOutOfOrderMessages()
      }, 50)
    })
    this.observer.observe(this.scrollTarget, { childList: true, subtree: true })
    this.insertDateSeparators()
    this.markOutOfOrderMessages()
    this.handleBeforeStreamRender = this.deduplicateAppend.bind(this)
    document.addEventListener("turbo:before-stream-render", this.handleBeforeStreamRender)
  }

  disconnect() {
    clearTimeout(this.pollTimeout)
    clearTimeout(this.loadOlderTimeout)
    clearTimeout(this.dateSepTimeout)
    clearTimeout(this.scrollBottomTimeout)
    document.removeEventListener("visibilitychange", this.handleVisibilityChange)
    window.removeEventListener("pageshow", this.handlePageShow)
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
    const isMac = /Mac|iPhone|iPad|iPod|macOS/.test(navigator.userAgentData?.platform ?? navigator.platform)
    el.textContent = (isMac ? "⌘" : "Ctrl") + "+Enter to send"
    el.classList.add("invisible")
  }

  onInput(event) {
    this.hintTarget.classList.toggle("invisible", event.target.value.trim() === "")
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
      .findLast(el => el.dataset.messageAuthorValue === currentUser())
    if (!last) return
    this.application.getControllerForElementAndIdentifier(last, "message")?.startEdit()
  }

  deduplicateAppend(event) {
    const stream = event.detail.newStream
    if (stream.target !== this.messagesTarget.id) return

    if (this.transportValue !== "polling" && this.hasTransportButtonTarget) {
      this.#flashTransportButton()
    }

    if (stream.action !== "append" && stream.action !== "prepend") return

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

  #flashTransportButton() {
    const el = this.transportButtonTarget
    el.classList.remove("activity-flash")
    el.getBoundingClientRect() // force reflow to restart animation
    el.classList.add("activity-flash")
  }

  #parseId(id) {
    const match = id?.match(/\d+$/)
    return match ? parseInt(match[0]) : null
  }

  maybeLoadOlder() {
    if (!this.hasMore || this.loadingOlder) return
    if (this.scrollTarget.scrollTop < 200) {
      clearTimeout(this.loadOlderTimeout)
      this.loadOlderTimeout = setTimeout(() => {
        if (!this.hasMore || this.loadingOlder) return
        this.loadOlderMessages()
      }, 50)
    }
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
        await new Promise(r => requestAnimationFrame(r))
        this.scrollTarget.scrollTop = prevScrollTop + (this.scrollTarget.scrollHeight - prevScrollHeight)
      }
    }

    this.loadOlderTarget.classList.add("hidden")
    this.loadingOlder = false
  }

  async pollForMessages() {
    if (this.polling) return

    if (this.atBottom && !this.messagesTarget.querySelector("[data-message-target='editor']:not(.hidden)")) {
      this.polling = true
      await this.#fetchLatest()
      this.polling = false
      this.#resetPollRing()
    }

    this.#schedulePoll()
  }

  async #fetchLatest() {
    const url = new URL(this.newerUrlValue, location.href)
    if (this.messagesDigest) url.searchParams.set("digest", this.messagesDigest)
    const response = await fetch(url, { headers: { Accept: "text/vnd.turbo-stream.html" } })
    if (response.ok) {
      const digest = response.headers.get("X-Messages-Digest")
      if (digest) this.messagesDigest = digest
      const html = await response.text()
      if (html.trim()) await Turbo.renderStreamMessage(html)
    }
  }

  #schedulePoll() {
    if (this.transportValue !== "polling") return
    clearTimeout(this.pollTimeout)
    this.pollTimeout = setTimeout(() => this.pollForMessages(), this.pollIntervalValue)
  }

  pollBarTargetConnected(el) {
    this.#startPollBar(el)
  }

  #resetPollRing() {
    if (!this.hasPollBarTarget) return
    this.#startPollBar(this.pollBarTarget)
  }

  #startPollBar(el) {
    el.style.animation = "none"
    el.getBoundingClientRect() // force reflow
    el.style.animation = `poll-countdown ${this.pollIntervalValue}ms linear forwards`
  }

  get latestMessageId() {
    const last = [...this.messagesTarget.children].findLast(el => !el.dataset.dateSeparator && el.id)
    return this.#parseId(last?.id)
  }

  get oldestMessageId() {
    const first = [...this.messagesTarget.children].find(el => !el.dataset.dateSeparator && el.id)
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

  markOutOfOrderMessages() {
    const messages = [...this.messagesTarget.children].filter(el => !el.dataset.dateSeparator && el.id)
    let prevId = null
    for (const el of messages) {
      const id = this.#parseId(el.id)
      if (prevId !== null && id < prevId) {
        el.dataset.outOfOrder = "true"
      } else {
        delete el.dataset.outOfOrder
      }
      prevId = id
    }
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
    clearTimeout(this.scrollBottomTimeout)
    this.scrollBottomTimeout = setTimeout(() => {
      this.scrollTarget.scrollTo({ top: this.scrollTarget.scrollHeight, behavior: "instant" })
    }, 100)
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

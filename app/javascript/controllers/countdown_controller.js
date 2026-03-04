import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["label", "bar"]
  static values = { minutes: { type: Number, default: 5 } }

  connect() {
    this.tick()
    this.interval = setInterval(() => this.tick(), 1000)
  }

  disconnect() {
    clearInterval(this.interval)
  }

  tick() {
    const now = new Date()
    const periodSecs = this.minutesValue * 60
    const secsIntoInterval = (now.getMinutes() % this.minutesValue) * 60 + now.getSeconds()
    const diff = Math.max(0, periodSecs - secsIntoInterval)
    const m = Math.floor(diff / 60).toString().padStart(2, "0")
    const s = (diff % 60).toString().padStart(2, "0")
    this.labelTarget.textContent = `${m}:${s}`
    if (this.hasBarTarget) {
      this.barTarget.style.width = `${(diff / periodSecs) * 100}%`
    }
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.tick()
    this.interval = setInterval(() => this.tick(), 1000)
  }

  disconnect() {
    clearInterval(this.interval)
  }

  tick() {
    const now = new Date()
    const next = new Date(now)
    if (now.getMinutes() < 30) {
      next.setMinutes(30, 0, 0)
    } else {
      next.setHours(next.getHours() + 1, 0, 0, 0)
    }
    const diff = Math.max(0, Math.floor((next - now) / 1000))
    const m = Math.floor(diff / 60).toString().padStart(2, "0")
    const s = (diff % 60).toString().padStart(2, "0")
    this.element.textContent = `${m}:${s}`
  }
}

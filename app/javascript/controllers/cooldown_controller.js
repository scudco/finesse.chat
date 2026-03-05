import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["bar"]
  static values = { duration: { type: Number, default: 5000 } }

  barTargetConnected(el) {
    el.style.transform = "scaleX(0)"
  }

  disconnect() {
    clearTimeout(this.cooldownTimeout)
  }

  start() {
    requestAnimationFrame(() => {
      this.element.disabled = true
      if (this.hasBarTarget) {
        this.barTarget.style.animation = "none"
        this.barTarget.getBoundingClientRect() // force reflow
        this.barTarget.style.animation = `poll-countdown ${this.durationValue}ms linear forwards`
      }

      // Turbo re-enables the submit button when the response arrives — re-disable immediately
      const form = this.element.closest("form")
      if (form) {
        const reDisable = () => {
          this.element.disabled = true
          form.removeEventListener("turbo:submit-end", reDisable)
        }
        form.addEventListener("turbo:submit-end", reDisable)
      }

      this.cooldownTimeout = setTimeout(() => {
        this.element.disabled = false
        if (this.hasBarTarget) this.barTarget.style.animation = "none"
      }, this.durationValue)
    })
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["label", "bar", "ring", "tooltip", "svg"]
  static values = { minutes: { type: Number, default: 5 } }

  connect() {
    this.tooltipOpen = false
    this.tick() // set initial value instantly, no transition yet
    requestAnimationFrame(() => requestAnimationFrame(() => {
      if (this.hasRingTarget) this.ringTarget.style.transition = "stroke-dashoffset 1000ms linear"
      if (this.hasSvgTarget) this.svgTarget.classList.remove("opacity-0")
    }))
    this.interval = setInterval(() => this.tick(), 1000)
  }

  disconnect() {
    clearInterval(this.interval)
    clearTimeout(this.tooltipTimeout)
  }

  tick() {
    const now = new Date()
    const periodSecs = this.minutesValue * 60
    const secsIntoInterval = (now.getMinutes() % this.minutesValue) * 60 + now.getSeconds()
    const diff = Math.max(0, periodSecs - secsIntoInterval)
    const m = Math.floor(diff / 60).toString().padStart(2, "0")
    const s = (diff % 60).toString().padStart(2, "0")

    if (this.hasLabelTarget) this.labelTarget.textContent = `${m}:${s}`
    if (this.hasBarTarget) this.barTarget.style.width = `${(diff / periodSecs) * 100}%`
    if (this.hasRingTarget) {
      const c = this.#circumference
      this.ringTarget.style.strokeDasharray = c
      this.ringTarget.style.strokeDashoffset = c * (1 - diff / periodSecs)
    }
  }

  toggleTooltip(event) {
    event.preventDefault()
    this.tooltipOpen = !this.tooltipOpen
    if (this.hasTooltipTarget) {
      this.tooltipTarget.style.opacity = this.tooltipOpen ? "1" : "0"
    }
    clearTimeout(this.tooltipTimeout)
    if (this.tooltipOpen) {
      this.tooltipTimeout = setTimeout(() => {
        this.tooltipOpen = false
        if (this.hasTooltipTarget) this.tooltipTarget.style.opacity = "0"
      }, 3000)
    }
  }

  get #circumference() {
    return 2 * Math.PI * this.ringTarget.r.baseVal.value
  }
}

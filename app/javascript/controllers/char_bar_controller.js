import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["bar"]
  static values  = { max: { type: Number, default: 2000 } }

  update(event) {
    const pct = event.target.value.length / this.maxValue
    const bar = this.barTarget
    bar.style.width = `${pct * 100}%`
    bar.classList.toggle("opacity-0", pct === 0)
    bar.style.backgroundColor = pct >= 0.9 ? "#ef4444" : pct >= 0.75 ? "#f59e0b" : "#3b82f6"
  }
}

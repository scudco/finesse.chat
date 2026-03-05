import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel"]

  connect() {
    this.hideTimeout = null
  }

  disconnect() {
    clearTimeout(this.hideTimeout)
    document.body.style.overflow = ""
  }

  open() {
    this.element.removeAttribute("hidden")
    requestAnimationFrame(() => {
      this.element.classList.remove("opacity-0", "pointer-events-none")
    })
    document.body.style.overflow = "hidden"
  }

  close() {
    this.element.classList.add("opacity-0", "pointer-events-none")
    this.hideTimeout = setTimeout(() => {
      this.element.setAttribute("hidden", "")
    }, 200)
    document.body.style.overflow = ""
  }

  escape(event) {
    if (event.key === "Escape" && !this.element.hasAttribute("hidden")) {
      this.close()
    }
  }

  backdropClick(event) {
    if (!this.panelTarget.contains(event.target)) {
      this.close()
    }
  }
}

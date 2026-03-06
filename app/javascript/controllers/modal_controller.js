import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "finesse-chat:show-on-launch"

export default class extends Controller {
  static targets = ["panel", "showOnLaunch"]
  static values = { autoOpen: Boolean }

  connect() {
    this.hideTimeout = null
    if (this.autoOpenValue && localStorage.getItem(STORAGE_KEY) !== "false") {
      requestAnimationFrame(() => this.open())
    }
    if (this.hasShowOnLaunchTarget) {
      this.showOnLaunchTarget.checked = localStorage.getItem(STORAGE_KEY) !== "false"
    }
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

  toggleShowOnLaunch(event) {
    if (event.target.checked) {
      localStorage.removeItem(STORAGE_KEY)
    } else {
      localStorage.setItem(STORAGE_KEY, "false")
    }
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
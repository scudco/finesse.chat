import { Controller } from "@hotwired/stimulus"

const THEMES = ["system", "light", "dark"]

export default class extends Controller {
  static targets = ["light", "dark"]
  connect() {
    this.theme = localStorage.getItem("theme") ?? "system"
    this.mediaQuery = window.matchMedia("(prefers-color-scheme: dark)")
    this.handleSystemChange = () => { if (this.theme === "system") this.apply() }
    this.mediaQuery.addEventListener("change", this.handleSystemChange)
    this.render()
  }

  disconnect() {
    this.mediaQuery.removeEventListener("change", this.handleSystemChange)
  }

  cycle() {
    this.theme = THEMES[(THEMES.indexOf(this.theme) + 1) % THEMES.length]
    if (this.theme === "system") {
      localStorage.removeItem("theme")
    } else {
      localStorage.setItem("theme", this.theme)
    }
    this.render()
  }

  render() {
    this.apply()
    const isDark = document.documentElement.classList.contains("dark")
    this.lightTarget.classList.toggle("hidden", isDark)
    this.darkTarget.classList.toggle("hidden", !isDark)
    this.element.style.opacity = this.theme === "system" ? "0.35" : "1"
    this.element.title = `Theme: ${this.theme}`
  }

  apply() {
    const dark = this.theme === "dark" || (this.theme === "system" && this.mediaQuery.matches)
    document.documentElement.classList.toggle("dark", dark)
  }
}
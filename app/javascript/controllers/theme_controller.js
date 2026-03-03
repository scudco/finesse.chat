import { Controller } from "@hotwired/stimulus"

const THEMES = ["system", "light", "dark"]

const SUN  = `<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="5"/><line x1="12" y1="1" x2="12" y2="3"/><line x1="12" y1="21" x2="12" y2="23"/><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"/><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"/><line x1="1" y1="12" x2="3" y2="12"/><line x1="21" y1="12" x2="23" y2="12"/><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"/><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"/></svg>`
const MOON = `<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/></svg>`

export default class extends Controller {
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
    this.element.innerHTML = isDark ? MOON : SUN
    this.element.style.opacity = this.theme === "system" ? "0.35" : "1"
    this.element.title = `Theme: ${this.theme}`
  }

  apply() {
    const dark = this.theme === "dark" || (this.theme === "system" && this.mediaQuery.matches)
    document.documentElement.classList.toggle("dark", dark)
  }
}
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const dt = new Date(this.element.dateTime)
    const now = new Date()
    const isToday = dt.toDateString() === now.toDateString()
    const time = dt.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })

    if (isToday) {
      this.element.textContent = time
    } else {
      const date = dt.toLocaleDateString([], { month: "short", day: "numeric", year: dt.getFullYear() === now.getFullYear() ? undefined : "numeric" })
      this.element.textContent = `${date}, ${time}`
    }

    this.element.title = dt.toLocaleString()
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  open() {
    window.dispatchEvent(new CustomEvent("open-modal"))
  }
}

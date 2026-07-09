// app/javascript/controllers/collapse_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content"]

  toggle() {
    this.contentTarget.classList.toggle("hidden")
    this.element.classList.toggle("open")
  }

  stop(event) {
    event.stopPropagation()
  }

  close() {
    this.contentTarget.classList.add("hidden")
    this.element.classList.remove("open")
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  connect() {
    this.outsideClickListener = this.handleOutsideClick.bind(this)
    document.addEventListener("click", this.outsideClickListener)
  }

  disconnect() {
    document.removeEventListener("click", this.outsideClickListener)
  }

  toggleMenu(event) {
    event.stopPropagation()
    this.menuTarget.classList.toggle("hidden")
  }

  handleOutsideClick(event) {
    if (!this.element.contains(event.target)) {
      this.menuTarget.classList.add("hidden")
    }
  }
}

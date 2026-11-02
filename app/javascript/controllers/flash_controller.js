// app/javascript/controllers/flash_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    duration: { type: Number, default: 2500 },
    autoDismiss: { type: Boolean, default: true }
  }

  connect() {
    if (!this.autoDismissValue) return

    this.timeout = setTimeout(() => {
      this.dismiss()
    }, this.durationValue)
  }

  disconnect() {
    clearTimeout(this.timeout)
    clearTimeout(this.removeTimeout)
  }

  dismiss() {
    if (!this.element.isConnected) return
    if (this.element.classList.contains("flash-hide")) return

    clearTimeout(this.timeout)

    this.element.classList.add("flash-hide")

    this.removeTimeout = setTimeout(() => {
      this.element.remove()
    }, 300)
  }
}

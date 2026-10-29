// app/javascript/controllers/calendar_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["clientName", "clientPhone", "clientList", "clearButton"]

  connect() {
    this.clients = {}
    if (this.hasClientListTarget) {
      Array.from(this.clientListTarget.options).forEach(option => {
        const name = option.value.trim().toLowerCase()
        const phone = option.dataset.phone || ""
        if (name) this.clients[name] = phone
      })
    }

    this.selectedClientName = null

    if (this.hasClientNameTarget) {
      const name = this.clientNameTarget.value.trim().toLowerCase()

      if (Object.hasOwn(this.clients, name)) {
        this.selectedClientName = name
      }

      this.toggleClearButton()
    }
  }

  updateClientInfo(event) {
    const enteredName = event.target.value.trim().toLowerCase()
    const hasClient = Object.hasOwn(this.clients, enteredName)

    if (hasClient) {
      const phone = this.clients[enteredName]

      if (this.hasClientPhoneTarget) {
        this.clientPhoneTarget.value = phone
        this.clientPhoneTarget.dispatchEvent(new CustomEvent("phone-mask:change"))
      }

      this.selectedClientName = enteredName
    } else {

      if (this.selectedClientName && this.hasClientPhoneTarget) {
        this.clientPhoneTarget.value = ""
        this.clientPhoneTarget.dispatchEvent(new CustomEvent("phone-mask:change"))
      }

      this.selectedClientName = null
    }

    this.toggleClearButton()
  }

  toggleClearButton() {
    if (!this.hasClearButtonTarget) return

    const empty = this.clientNameTarget.value.trim() === ""

    this.clearButtonTarget.classList.toggle("hidden", empty)
  }

  clearClientField() {
    this.clientNameTarget.value = ""
    this.selectedClientName = null

    if (this.hasClientPhoneTarget) {
      this.clientPhoneTarget.value = ""
      this.clientPhoneTarget.dispatchEvent(new CustomEvent("phone-mask:change"))
    }

    this.toggleClearButton()

    if (this.clientNameTarget.showPicker) {
      this.clientNameTarget.showPicker()
    } else {
      this.clientNameTarget.dispatchEvent( new Event("input", { bubbles: true }))
    }
  }
}

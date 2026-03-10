import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["clientName", "clientPhone", "clientList", "clearButton"]

  connect() {
    console.log("✅ CalendarController connected")

    this.clients = {}
    if (this.hasClientListTarget) {
      Array.from(this.clientListTarget.options).forEach(option => {
        const name = option.value.trim().toLowerCase()
        const phone = option.dataset.phone || ""
        if (name) this.clients[name] = phone
      })
    }

    if (this.hasClientNameTarget) {
      this.updateClientInfo({ target: this.clientNameTarget })
      this.toggleClearButton()
    }
  }

  updateClientInfo(event) {
    const enteredName = event.target.value.trim().toLowerCase()
    const phone = this.clients[enteredName]

    if (phone) {
      this.clientPhoneTarget.value = phone
    } else {
      this.clientPhoneTarget.value = ""
    }

    this.toggleClearButton()
  }

  toggleClearButton() {
    if (!this.hasClearButtonTarget) return

    if (this.clientNameTarget.value.trim() === "") {
      this.clearButtonTarget.classList.add("hidden")
    } else {
      this.clearButtonTarget.classList.remove("hidden")
    }
  }

  clearClientField() {
    this.clientNameTarget.value = ""
    this.clientPhoneTarget.value = ""
    this.toggleClearButton()

    if (this.clientNameTarget.showPicker) {
      this.clientNameTarget.showPicker()
    } else {
      this.clientNameTarget.dispatchEvent(new Event("input"))
    }
  }
}

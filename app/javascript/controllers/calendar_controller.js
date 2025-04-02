import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["clientName", "clientPhone", "clientList"]

  connect() {
    console.log("✅ CalendarController connected")

    // Підготовка мапи клієнтів
    this.clients = {}
    if (this.hasClientListTarget) {
      Array.from(this.clientListTarget.options).forEach(option => {
        const name = option.value.trim().toLowerCase()
        const phone = option.dataset.phone || ""
        if (name) this.clients[name] = phone
      })
    }

    // 👉 Автопідстановка телефону після завантаження
    if (this.hasClientNameTarget) {
      this.updateClientInfo({ target: this.clientNameTarget })
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
  }
}

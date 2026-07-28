// app/javascript/controllers/appointment_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "appointmentTime",
    "endTime",
    "timeError",
    "saveButton"
  ]

  roundToNearestFive(event) {
    const input = event.target
    const value = input.value

    if (!value.match(/^\d{2}:\d{2}$/)) return

    const [hours, minutes] = value.split(":").map(Number)
    const roundedMinutes = Math.round(minutes / 5) * 5
    const formattedMinutes = String(roundedMinutes % 60).padStart(2, "0")
    const formattedHours = String((hours + Math.floor(roundedMinutes / 60)) % 24).padStart(2, "0")

    input.value = `${formattedHours}:${formattedMinutes}`
  }

  validateTimes() {
    const start = this.appointmentTimeTarget.value
    const end = this.endTimeTarget.value

    if (!start || !end) {
      this.timeErrorTarget.classList.add("hidden")
      this.saveButtonTarget.disabled = false
      return
    }

    if (end <= start) {
      this.timeErrorTarget.classList.remove("hidden")
      this.saveButtonTarget.disabled = true
    } else {
      this.timeErrorTarget.classList.add("hidden")
      this.saveButtonTarget.disabled = false
    }
  }
}

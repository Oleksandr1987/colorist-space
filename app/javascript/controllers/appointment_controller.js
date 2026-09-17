// app/javascript/controllers/appointment_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "appointmentTime",
    "endTime",
    "timeError",
    "saveButton",
    "date",
    "slots",
    "slotsList"
  ]

  static values = {
    freeSlotsUrl: String,
    noFreeSlots: String
  }

  connect() {
    this.loadSlots()
  }

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

  async loadSlots() {
    if (!this.hasDateTarget || !this.hasSlotsListTarget) return

    const date = this.dateTarget.value
    if (!date) return

    const normalizedDate = this.normalizeDate(date)
    const url = new URL(this.freeSlotsUrlValue, window.location.origin)

    url.searchParams.set("date", normalizedDate)

    try {
      const response = await fetch(url, {
        headers: {
          Accept: "application/json"
        }
      })

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`)
      }

      const slots = await response.json()

      this.renderSlots(slots)
    } catch (error) {
      console.error("Unable to load appointment slots:", error)

      this.slotsListTarget.replaceChildren()
    }
  }

  renderSlots(slots) {
    this.slotsListTarget.replaceChildren()

    if (slots.length === 0) {
      const empty = document.createElement("div")

      empty.className = "appointment-slots-empty"
      empty.textContent = this.noFreeSlotsValue

      this.slotsListTarget.appendChild(empty)
      return
    }

    slots.forEach(slot => {
      const button = document.createElement("button")

      button.type = "button"
      button.className = "appointment-slot"
      button.textContent = `${slot.start}–${slot.end}`
      button.dataset.start = slot.start
      button.dataset.end = slot.end
      button.dataset.action = "click->appointment#selectSlot"

      this.slotsListTarget.appendChild(button)
    })
  }

  selectSlot(event) {
    const button = event.currentTarget

    this.appointmentTimeTarget.value = button.dataset.start
    this.endTimeTarget.value = button.dataset.end
    this.validateTimes()

    this.slotsListTarget
      .querySelectorAll(".appointment-slot")
      .forEach(slot => slot.classList.remove("selected"))

    button.classList.add("selected")
  }

  normalizeDate(value) {
    if (/^\d{4}-\d{2}-\d{2}$/.test(value)) {
      return value
    }

    const match = value.match(/^(\d{2})\.(\d{2})\.(\d{4})$/)

    if (!match) return value

    const [, day, month, year] = match

    return `${year}-${month}-${day}`
  }
}

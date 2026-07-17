// app/javascript/controllers/appointment_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "list", "selected",
    "serviceSelected", "hiddenInput",
    "appointmentTime", "endTime", "timeError", "saveButton"
  ]

  static values = {
    nothingSelected: String
  }

  connect() {
    this.selected = {
      service: []
    }

    if (this.hasHiddenInputTarget && this.hiddenInputTarget.value) {
      const existingIds = this.hiddenInputTarget.value
        .split(',')
        .map(id => parseInt(id))
        .filter(Boolean)

      if (existingIds.length > 0) {
        document.querySelectorAll('input[type=checkbox][name="appointment[modal_dummy][]"]').forEach((checkbox) => {
          const id = parseInt(checkbox.value)
          const type = checkbox.dataset.type
          if (existingIds.includes(id)) {
            checkbox.checked = true
            this.selected[type].push({
              id: checkbox.value,
              subtype: checkbox.dataset.subtype,
              price: checkbox.dataset.price
            })
          }
        })
      }
    }

    this.recalculate()
    this.updateSelected()
  }

  open(event) {
    const type = event.currentTarget.dataset.type
    this.closeAllModals()
    const modal = document.querySelector(`.wizard-modal[data-type='${type}']`)
    if (modal) modal.classList.remove("hidden")
  }

  close(event) {
    const modal =
      event.currentTarget.closest(".wizard-modal") ||
      event.currentTarget.closest(".wizard-modal-content")?.parentElement

    if (modal) modal.classList.add("hidden")
  }

  closeAllModals() {
    document.querySelectorAll(".wizard-modal").forEach(m => m.classList.add("hidden"))
  }

  toggleService(event) {
    const input = event.target
    const id = input.value
    const subtype = input.dataset.subtype
    const price = input.dataset.price
    const type = input.dataset.type

    if (!type) return

    if (input.checked) {
      this.selected[type].push({ id, subtype, price })
    } else {
      this.selected[type] = this.selected[type].filter(s => s.id !== id)
    }

    this.recalculate()
    this.updateSelected()
  }

  updateSelected() {
    const all = [...this.selected.service]

    if (this.hasHiddenInputTarget) {
      const container = this.hiddenInputTarget.parentElement
      container.querySelectorAll("input[name='appointment[service_ids][]']").forEach(e => e.remove())

      all.forEach(s => {
        const input = document.createElement("input")
        input.type = "hidden"
        input.name = "appointment[service_ids][]"
        input.value = s.id
        container.appendChild(input)
      })

      this.hiddenInputTarget.value = ""
    }

    this.updateTargetContent("serviceSelected", this.selected.service)
  }

  updateTargetContent(targetName, items) {
    const target = `${targetName}Target`

    if (!this[target]) return

    const el = this[target]

    if (items.length === 0) {
      el.innerHTML = `<span class="placeholder">${this.nothingSelectedValue}</span>`
    } else {
      el.innerHTML = items.map(s => `${s.subtype} (${s.price} ₴)`).join(", ")
    }
  }

  search(event) {
    const query = event.target.value.toLowerCase()
    const modal = event.target.closest(".wizard-modal")
    modal.querySelectorAll(".wizard-check-row").forEach(opt => {
      opt.classList.toggle("hidden", !opt.textContent.toLowerCase().includes(query))
    })
  }

  recalculate() {
    let total = 0
    const all = [...this.selected.service]
    all.forEach(item => {
      const price = parseInt(item.price)
      if (!isNaN(price)) total += price
    })
    if (this.hasTotalTarget) this.totalTarget.textContent = total
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
}

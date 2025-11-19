// app/javascript/controllers/appointment_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "checkboxes", "total", "modal", "list", "selected", "field",
    "serviceSelected", "preparationSelected", "careProductSelected", "hiddenInput"
  ]

  connect() {
    this.selected = {
      service: [],
      preparation: [],
      care_product: []
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
    const modal = document.querySelector(`.modal[data-type='${type}']`)
    if (modal) modal.classList.remove("hidden")
  }

  close(event) {
    const modal =
      event.currentTarget.closest(".modal") ||
      event.currentTarget.closest(".modal-content")?.parentElement

    if (modal) modal.classList.add("hidden")
  }

  closeAllModals() {
    document.querySelectorAll(".modal").forEach(m => m.classList.add("hidden"))
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
    const all = [...this.selected.service, ...this.selected.preparation, ...this.selected.care_product]

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
    this.updateTargetContent("preparationSelected", this.selected.preparation)
    this.updateTargetContent("careProductSelected", this.selected.care_product)
  }

  updateTargetContent(targetName, items) {
    const el = this[`${targetName}Target`]
    if (items.length === 0) {
      el.innerHTML = `<span class="placeholder">${I18n.t("appointments.form.nothing_selected")}</span>`
    } else {
      el.innerHTML = items.map(s => `${s.subtype} (${s.price} ₴)`).join(", ")
    }
  }

  search(event) {
    const query = event.target.value.toLowerCase()
    const modal = event.target.closest(".modal")
    modal.querySelectorAll(".service-option").forEach(opt => {
      opt.classList.toggle("hidden", !opt.textContent.toLowerCase().includes(query))
    })
  }

  recalculate() {
    let total = 0
    const all = [...this.selected.service, ...this.selected.preparation, ...this.selected.care_product]
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
}

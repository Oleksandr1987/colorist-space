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
    this.hiddenInputTarget.value = all.map(s => s.id).join(",")

    this.updateTargetContent("serviceSelected", this.selected.service)
    this.updateTargetContent("preparationSelected", this.selected.preparation)
    this.updateTargetContent("careProductSelected", this.selected.care_product)
  }

  updateTargetContent(targetName, items) {
    const el = this[`${targetName}Target`]
    if (items.length === 0) {
      el.innerHTML = '<span class="placeholder">Нічого не вибрано</span>'
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
}

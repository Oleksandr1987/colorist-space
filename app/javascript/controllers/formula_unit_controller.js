// app/javascript/controllers/formula_unit_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "input"]

  connect() {
    const unit = this.inputTarget.value

    this.updateButtons(unit)
  }

  select(event) {
    const unit = event.currentTarget.dataset.value

    this.inputTarget.value = unit
    this.updateButtons(unit)

    this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }

  updateButtons(unit) {
    this.buttonTargets.forEach(button => {
      const active = button.dataset.value === unit

      button.classList.toggle("active", active)
      button.setAttribute("aria-pressed", String(active))
    })
  }
}


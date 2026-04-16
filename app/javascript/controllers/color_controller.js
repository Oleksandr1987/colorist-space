// app/javascript/controllers/color_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "rows", "list"]

  connect() {
    this.handleOpen = this.handleOpen.bind(this)
    window.addEventListener("color:open", this.handleOpen)
  }

  disconnect() {
    window.removeEventListener("color:open", this.handleOpen)
  }
  handleOpen(event) {
    this.currentStep = event.detail.step
    this.modalTarget.classList.remove("hidden")

    if (this.rowsTarget.children.length === 0) {
      this.addRow()
    }
  }

  get rowsContainer() {
    return this.rowsTarget
  }

  closeModal() {
    const modal = document.querySelector("[data-color-target='modal']")
    const rows = document.querySelector("[data-color-target='rows']")

    modal.classList.add("hidden")
    rows.innerHTML = ""
  }

  // ---------- ADD ROW ----------
  addRow() {
    const container = this.rowsTarget
    const row = document.createElement("div")
    row.className = "color-row"

    row.innerHTML = `
      <input type="text" placeholder="Color">
      <input type="text" placeholder="Brand">
      <input type="text" placeholder="Amount">
      <button type="button" class="color-remove">×</button>
    `

    row.querySelector(".color-remove").onclick = () => row.remove()

    const amountInput = row.querySelector("input:last-of-type")

    amountInput.addEventListener("input", () => {
      let val = amountInput.value
      val = val.replace(/[^0-9.,]/g, "")
      val = val.replace("-", "")
      amountInput.value = val
    })

    this.rowsContainer.appendChild(row)
  }

  save() {
    if (!this.currentStep) return

    const rows = this.rowsTarget.querySelectorAll(".color-row")

    rows.forEach(row => {
      const [shadeInput, brandInput, amountInput] = row.querySelectorAll("input")

      let shade = shadeInput.value.trim()
      let brand = brandInput.value.trim()
      let amount = amountInput.value.trim()

      if (!shade || !amount) return

      amount = amount.replace(",", ".")
      if (parseFloat(amount) <= 0) return

      const template = this.currentStep.querySelector(
        "[data-formula-target='ingredientTemplate']"
      )

      const uid = Date.now()
      let html = template.innerHTML.replace(/NEW_RECORD/g, uid)

      const wrapper = document.createElement("div")
      wrapper.innerHTML = html

      const hidden = wrapper.querySelector(".ingredient-fields")
      hidden.dataset.id = uid 

      hidden.querySelector("[data-field='shade']").value = shade
      hidden.querySelector("[data-field='brand']").value = brand
      hidden.querySelector("[data-field='amount']").value = amount

      this.currentStep
        .querySelector("[data-formula-target='colorsList']")
        .appendChild(hidden)

      const display = document.createElement("div")
      display.className = "color-row-display"
      display.dataset.id = uid

      display.innerHTML = `
        <div class="color-left">
          <span class="shade">${shade}</span>
          <span class="brand">${brand}</span>
        </div>
        <div class="color-right">
          <span class="amount">${amount}g</span>
          <button type="button" class="remove"
            data-action="click->formula#removeColor">×</button>
        </div>
      `

      this.currentStep
        .querySelector("[data-color-target='list']")
        .appendChild(display)
    })

    this.rowsTarget.innerHTML = ""
    this.closeModal()

    window.dispatchEvent(
      new CustomEvent("formula:colorAmountChanged", {
        detail: {
          total: this.calculateTotalAmount(),
          stepId: this.currentStep.dataset.stepId
        }
      })
    )
  }

  calculateTotalAmount() {
    let total = 0

    this.currentStep
      .querySelectorAll("[name*='[amount]']")
      .forEach(input => {
        total += parseFloat(input.value || 0)
      })

    return total
  }

  stepId() {
    return this.element.closest(".formula-card").dataset.stepId
  }

  stop(e) {
    e.stopPropagation()
  }
}

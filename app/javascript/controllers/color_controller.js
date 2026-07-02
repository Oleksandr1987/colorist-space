// app/javascript/controllers/color_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "rows", "actions", "paletteTemplate", "shadeTemplate", "list" ]

  static values = {
    deleteIcon: String
  }

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
    this.reset()
  }

  closeModal() {
    this.modalTarget.classList.add("hidden")
    this.reset()
  }

  reset() {
    this.rowsTarget.innerHTML = ""
    this.actionsTarget.classList.add("hidden")
    this.currentPalette = null
    this.addPalette()
  }

  addPalette() {
    this.rowsTarget.insertAdjacentHTML(
      "beforeend",
      this.paletteTemplateTarget.innerHTML
    )
  }

  selectPalette(event) {
    const select = event.target
    const option = select.selectedOptions[0]

    if (!option) {
      return
    }

    this.currentPalette = {
      id: option.value,
      brand: option.dataset.brand,
      price: option.dataset.price
    }

    select.closest(".palette-row").remove()

    this.actionsTarget.classList.remove("hidden")
    this.createShadeRow()
  }

  createShadeRow() {
    const wrapper = document.createElement("div")

    wrapper.innerHTML = this.shadeTemplateTarget.innerHTML

    const row = wrapper.firstElementChild

    row.dataset.productId = this.currentPalette.id
    row.dataset.price = this.currentPalette.price
    row.dataset.brand = this.currentPalette.brand

    row.querySelector(
      ".color-brand"
    ).textContent =
      this.currentPalette.brand

    const amountInput = row.querySelector(".color-amount")

    amountInput.addEventListener(
      "input",
      () => {
        let value = amountInput.value

        value = value.replace(
          /[^0-9.,]/g,
          ""
        )

        amountInput.value = value

        amountInput.classList.remove(
          "color-error"
        )
      }
    )

    this.rowsTarget.appendChild(row)
  }

    addShade() {
    if (!this.currentPalette) {
      return
    }

    this.createShadeRow()
  }

  changePalette() {
    if (
      this.rowsTarget.querySelector(".palette-row")
    ) {
      return
    }
    this.currentPalette = null
    this.addPalette()
  }

  removeRow(event) {
    event.target.closest(".color-row").remove()

    if (
      this.rowsTarget.querySelectorAll(".color-row").length === 0
    ) {
      this.actionsTarget.classList.add("hidden")

      if (
        this.rowsTarget.querySelectorAll(".palette-row").length === 0
      ) {
        this.addPalette()
      }
    }
  }

  save() {
    if (!this.currentStep) return

    const rows = this.rowsTarget.querySelectorAll(".color-row")

    let hasErrors = false

    rows.forEach(row => {
      const shadeInput = row.querySelector(".color-shade")

      const amountInput = row.querySelector(".color-amount")

      if (!shadeInput.value.trim()) {
        shadeInput.classList.add("color-error")
        hasErrors = true
      }

      if (!amountInput.value.trim()) {
        amountInput.classList.add("color-error")
        hasErrors = true
      }
    })

    if (hasErrors) {
      return
    }

    const stepId = this.currentStep.dataset.stepId

    rows.forEach(row => {

      const brand = row.dataset.brand
      const shade = row.querySelector(".color-shade").value.trim()

      let amount = row.querySelector(".color-amount").value.trim()

      amount = amount.replace(",", ".")

      if (parseFloat(amount) <= 0) {
        return
      }

      const template = this.currentStep.querySelector(
        "[data-formula-target='ingredientTemplate']"
      )

      const uid = `new_${Date.now()}_${Math.random().toString(36).slice(2)}`

      let html = template.innerHTML
        .replace(/NEW_ID/g, uid)
        .replace(/STEP_ID/g, stepId)

      const wrapper = document.createElement("div")

      wrapper.innerHTML = html

      const hidden = wrapper.querySelector(".ingredient-fields")

      hidden.dataset.id = uid
      hidden.querySelector("[data-field='brand']").value = brand
      hidden.querySelector("[data-field='shade']").value = shade
      hidden.querySelector("[data-field='amount']").value = amount
      hidden.querySelector("[data-field='formula_product_id']").value = row.dataset.productId
      hidden.querySelector("[data-field='price']").value = row.dataset.price

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

          <button
            type="button"
            class="remove"
            data-action="click->formula#removeColor">
            <img
              src="${this.deleteIconValue}"
              alt="Delete"
              class="clear-icon">
          </button>
        </div>
      `

      this.currentStep
        .querySelector("[data-color-target='list']")
        .appendChild(display)
    })

    this.closeModal()

    requestAnimationFrame(() => {

      window.dispatchEvent(
        new CustomEvent(
          "formula:colorAmountChanged",
          {
            detail: {
              total: this.calculateTotalAmount(),
              stepId: this.currentStep.dataset.stepId
            }
          }
        )
      )

      window.dispatchEvent(
        new CustomEvent("formula:changed")
      )

      window.dispatchEvent(
        new CustomEvent("formula:firstStepFilled")
      )
    })
  }

  calculateTotalAmount() {
    let total = 0

    this.currentStep
      .querySelectorAll(".ingredient-fields")
      .forEach(wrapper => {

        const destroyInput = wrapper.querySelector(
          "[data-field='destroy']"
        )

        if (destroyInput?.value === "1") return

        const amountInput = wrapper.querySelector(
          "[data-field='amount']"
        )

        if (!amountInput) return

        const value = parseFloat(amountInput.value || 0)

        if (!isNaN(value)) {
          total += value
        }
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

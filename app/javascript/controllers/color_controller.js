// app/javascript/controllers/color_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "rows", "actions", "paletteTemplate", "shadeTemplate", "list", "saveBtn"]

  static values = {
    deleteIcon: String,
    editIcon: String
  }

  connect() {
    this.handleOpen = this.handleOpen.bind(this)
    window.addEventListener("color:open", this.handleOpen)
    this.editingId = null
  }

  disconnect() {
    window.removeEventListener("color:open", this.handleOpen)
  }

  handleOpen(event) {
    this.currentStep = event.detail.step
    this.editingId = event.detail.ingredientId || null
    this.modalTarget.classList.remove("hidden")

    if (this.editingId) {
      this.loadIngredientForEdit()
    } else {
      this.reset()
    }
  }

  closeModal() {
    this.modalTarget.classList.add("hidden")
    this.reset()
  }

  reset() {
    this.rowsTarget.innerHTML = ""
    this.actionsTarget.classList.add("hidden")
    this.currentPalette = null
    this.editingId = null
    this.saveBtnTarget.disabled = true
    this.addPalette()
  }

  addPalette() {
    this.rowsTarget.insertAdjacentHTML("beforeend", this.paletteTemplateTarget.innerHTML)
  }

  selectPalette(event) {
    const select = event.target
    const option = select.selectedOptions[0]
    if (!option || !option.value) {
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
    if (!this.currentPalette) return

    const wrapper = document.createElement("div")

    wrapper.innerHTML = this.shadeTemplateTarget.innerHTML

    const row = wrapper.firstElementChild

    row.dataset.productId = this.currentPalette.id
    row.dataset.price = this.currentPalette.price
    row.dataset.brand = this.currentPalette.brand
    row.querySelector(".color-brand").textContent = this.currentPalette.brand

    const shadeInput = row.querySelector(".color-shade")
    const amountInput = row.querySelector(".color-amount")

    shadeInput.addEventListener("input", () => {
      shadeInput.classList.remove("color-error")
      this.updateSaveButton()
    })

    amountInput.addEventListener("input", () => {
      let value = amountInput.value

      value = value.replace(/[^0-9.,]/g, "")

      amountInput.value = value
      amountInput.classList.remove("color-error")

      this.updateSaveButton()
    })

    this.rowsTarget.appendChild(row)
    this.updateSaveButton()
  }

  loadIngredientForEdit() {
    this.rowsTarget.innerHTML = ""
    this.actionsTarget.classList.add("hidden")
    this.saveBtnTarget.disabled = true

    const hidden = this.currentStep.querySelector(`.ingredient-fields[data-id="${CSS.escape(this.editingId)}"]`)
    if (!hidden) {
      this.closeModal()
      return
    }

    const brandInput = hidden.querySelector("[data-field='brand']")
    const shadeInput = hidden.querySelector("[data-field='shade']")
    const amountInput = hidden.querySelector("[data-field='amount']")
    const productInput = hidden.querySelector("[data-field='formula_product_id']")
    const priceInput = hidden.querySelector("[data-field='price']")

    this.currentPalette = {
      id: productInput?.value || "",
      brand: brandInput?.value || "",
      price: priceInput?.value || ""
    }

    this.createShadeRow()

    const row = this.rowsTarget.querySelector(".color-row")

    if (!row) return

    row.querySelector(".color-shade").value = shadeInput?.value || ""
    row.querySelector(".color-amount").value = amountInput?.value || ""

    this.updateSaveButton()
  }

  addShade() {
    if (!this.currentPalette) {
      return
    }

    this.createShadeRow()
  }

  changePalette() {
    if (this.rowsTarget.querySelector(".palette-row")) {
      return
    }
    this.currentPalette = null
    this.addPalette()
  }

  removeRow(event) {
    event.target.closest(".color-row")?.remove()

    if (this.rowsTarget.querySelectorAll(".color-row").length === 0) {
      this.actionsTarget.classList.add("hidden")

      if (this.rowsTarget.querySelectorAll(".palette-row").length === 0) {
        this.addPalette()
      }
    }

    this.updateSaveButton()
  }

  updateSaveButton() {
    const rows = this.rowsTarget.querySelectorAll(".color-row")
    if (rows.length === 0) {
      this.saveBtnTarget.disabled = true
      return
    }

    const allValid = Array.from(rows).every(row => {
      const shade = row.querySelector(".color-shade").value.trim()
      const amountValue = row.querySelector(".color-amount").value.trim().replace(",", ".")
      const amount = parseFloat(amountValue)

      return (shade !== "" && amountValue !== "" && !Number.isNaN(amount) && amount > 0)
    })

    this.saveBtnTarget.disabled = !allValid
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

      const amount = parseFloat(amountInput.value.trim().replace(",", "."))

      if (!amountInput.value.trim() || Number.isNaN(amount) || amount <= 0) {
        amountInput.classList.add("color-error")
        hasErrors = true
      }
    })

    if (hasErrors) {
      return
    }

    const stepId = this.currentStep.dataset.stepId
    if (this.editingId) {
      this.updateIngredient(rows[0])

      const total = this.calculateTotalAmount()

      this.closeModal()
      this.dispatchColorChanged(total, stepId)

      return
    }

    rows.forEach(row => {
      this.createIngredient(row, stepId)
    })

    const total = this.calculateTotalAmount()

    this.closeModal()
    this.dispatchColorChanged(total, stepId, true)
  }

  updateIngredient(row) {
    const hidden = this.currentStep.querySelector(`.ingredient-fields[data-id="${CSS.escape(this.editingId)}"]`)
    const display = this.currentStep.querySelector(`.color-row-display[data-id="${CSS.escape(this.editingId)}"]`)

    if (!hidden || !display) return

    const brand = row.dataset.brand
    const shade = row.querySelector(".color-shade").value.trim()
    const amount = row.querySelector(".color-amount").value.trim().replace(",", ".")

    hidden.querySelector("[data-field='brand']").value = brand
    hidden.querySelector("[data-field='shade']").value = shade
    hidden.querySelector("[data-field='amount']").value = amount
    hidden.querySelector("[data-field='formula_product_id']").value = row.dataset.productId
    hidden.querySelector("[data-field='price']").value = row.dataset.price

    display.querySelector(".brand").textContent = brand
    display.querySelector(".shade").textContent = shade
    display.querySelector(".amount").textContent = `${amount}g`
  }

  createIngredient(row, stepId) {
    const brand = row.dataset.brand
    const shade = row.querySelector(".color-shade").value.trim()
    const amount = row.querySelector(".color-amount").value.trim().replace(",", ".")

    if (parseFloat(amount) <= 0) {
      return
    }

    const template = this.currentStep.querySelector("[data-formula-target='ingredientTemplate']")

    if (!template) return

    const uid = `new_${Date.now()}_${Math.random().toString(36).slice(2)}`
    const html = template.innerHTML.replace(/NEW_ID/g, uid).replace(/STEP_ID/g, stepId)
    const wrapper = document.createElement("div")

    wrapper.innerHTML = html

    const hidden = wrapper.querySelector(".ingredient-fields")

    hidden.dataset.id = uid

    hidden.querySelector("[data-field='brand']").value = brand
    hidden.querySelector("[data-field='shade']").value = shade
    hidden.querySelector("[data-field='amount']").value = amount
    hidden.querySelector("[data-field='formula_product_id']").value = row.dataset.productId
    hidden.querySelector("[data-field='price']").value = row.dataset.price

    this.currentStep.querySelector("[data-formula-target='colorsList']").appendChild(hidden)

    const display = document.createElement("div")

    display.className = "color-row-display"
    display.dataset.id = uid

    display.innerHTML = `
      <div class="color-left">
        <span class="shade"></span>
        <span class="brand"></span>
      </div>

      <div class="color-right">
        <span class="amount"></span>

        <div class="color-actions">
          <button type="button" class="edit-btn" data-action="click->formula#editColor">
            <img class="edit-icon" alt="Edit">
          </button>

          <button type="button" class="delete-btn" data-action="click->formula#removeColor">
            <img class="delete-icon" alt="Delete">
          </button>
        </div>
      </div>
    `

    display.querySelector(".shade").textContent = shade
    display.querySelector(".brand").textContent = brand
    display.querySelector(".amount").textContent = `${amount}g`
    display.querySelector(".edit-icon").src = this.editIconValue
    display.querySelector(".delete-icon").src = this.deleteIconValue

    this.currentStep.querySelector("[data-color-target='list']").appendChild(display)
  }

  dispatchColorChanged(total, stepId, firstStepFilled = false) {
    requestAnimationFrame(() => {
      window.dispatchEvent(new CustomEvent("formula:colorAmountChanged", { detail: {total, stepId } }))
      window.dispatchEvent(new CustomEvent("formula:changed"))

      if (firstStepFilled) {
        window.dispatchEvent(new CustomEvent("formula:firstStepFilled"))
      }
    })
  }

  calculateTotalAmount() {
    if (!this.currentStep) return 0

    let total = 0

    this.currentStep
      .querySelectorAll(".ingredient-fields")
      .forEach(wrapper => {
        const destroyInput = wrapper.querySelector("[data-field='destroy']")
        if (destroyInput?.value === "1") return

        const amountInput = wrapper.querySelector("[data-field='amount']")
        if (!amountInput) return

        const value = parseFloat(amountInput.value || 0)
        if (!Number.isNaN(value)) {
          total += value
        }
      })

    return total
  }

  stepId() {
    return this.element.closest(".formula-card").dataset.stepId
  }

  stop(event) {
    event.stopPropagation()
  }
}

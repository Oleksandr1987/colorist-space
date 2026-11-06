// app/javascript/controllers/additive_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "rows", "actions", "productTemplate", "rowTemplate", "saveBtn"]

  static values = {
    deleteIcon: String,
    editIcon: String
  }

  connect() {
    this.handleOpen = this.handleOpen.bind(this)
    window.addEventListener("additive:open", this.handleOpen)
    this.editingId = null
  }

  disconnect() {
    window.removeEventListener("additive:open", this.handleOpen)
  }

  handleOpen(event) {
    if (!event.detail?.step) return

    this.currentStep = event.detail.step
    this.editingId = event.detail.ingredientId || null
    this.modalTarget.classList.remove("hidden")

    if (this.editingId) {
      this.loadForEdit()
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
    this.saveBtnTarget.disabled = true
    this.currentProduct = null
    this.editingId = null
    this.addProductSelector()
  }

  addProductSelector() {
    this.rowsTarget.insertAdjacentHTML("beforeend", this.productTemplateTarget.innerHTML)
  }

  selectProduct(event) {
    const option = event.target.selectedOptions[0]
    if (!option?.value) return

    this.currentProduct = {
      id: option.value,
      brand: option.dataset.brand || "",
      name: option.dataset.name || "",
      price: option.dataset.price || "0",
      unit: option.dataset.unit || "g"
    }

    event.target.closest(".palette-row")?.remove()
    this.createRow()

    if (!this.editingId) {
      this.actionsTarget.classList.remove("hidden")
    }
  }

  createRow() {
    if (!this.currentProduct) return

    const wrapper = document.createElement("div")
    wrapper.innerHTML = this.rowTemplateTarget.innerHTML

    const row = wrapper.firstElementChild

    row.dataset.productId = this.currentProduct.id
    row.dataset.brand = this.currentProduct.brand
    row.dataset.price = this.currentProduct.price
    row.dataset.unit = this.currentProduct.unit

    row.querySelector(".color-brand").textContent = this.currentProduct.brand
    row.querySelector(".additive-name").value = this.currentProduct.name || this.currentProduct.brand
    row.querySelector(".additive-amount").addEventListener("input", event => {
      event.target.value = event.target.value.replace(/[^0-9.,]/g, "")
      event.target.classList.remove("color-error")
      this.updateSaveButton()
    })

    this.rowsTarget.appendChild(row)
    this.updateSaveButton()
  }

  addRow() {
    this.createRow()
  }

  changeProduct() {
    if (this.editingId) return
    if (this.rowsTarget.querySelector(".palette-row")) return

    this.currentProduct = null
    this.addProductSelector()
  }

  removeRow(event) {
    event.currentTarget.closest(".color-row")?.remove()

    if (!this.rowsTarget.querySelector(".color-row")) {
      this.actionsTarget.classList.add("hidden")

      if (!this.rowsTarget.querySelector(".palette-row")) {
        this.addProductSelector()
      }
    }

    this.updateSaveButton()
  }

  updateSaveButton() {
    const rows = [...this.rowsTarget.querySelectorAll(".color-row")]

    this.saveBtnTarget.disabled =
      rows.length === 0 ||
      !rows.every(row => {
        const amount = Number(row.querySelector(".additive-amount").value.replace(",", "."))

        return Number.isFinite(amount) && amount > 0
      })
  }

  loadForEdit() {
    this.rowsTarget.innerHTML = ""
    this.actionsTarget.classList.add("hidden")

    const hidden = this.findIngredient(this.editingId)

    if (!hidden) {
      this.closeModal()
      return
    }

    const value = field => hidden.querySelector(`[data-field="${field}"]`)?.value || ""
    const productId = value("formula_product_id")
    const option = [...this.productTemplateTarget.content.querySelectorAll("option")].find(item => item.value === productId)

    this.currentProduct = {
      id: productId,
      brand: value("brand"),
      name: value("shade"),
      price: value("price"),
      unit: option?.dataset.unit || "g"
    }

    this.createRow()

    const row = this.rowsTarget.querySelector(".color-row")
    row.querySelector(".additive-name").value = value("shade")
    row.querySelector(".additive-amount").value = value("amount")

    this.updateSaveButton()
  }

  findIngredient(id) {
    return [...this.currentStep.querySelectorAll(".ingredient-fields")].find(element => element.dataset.id === String(id))
  }

  save() {
    if (!this.currentStep) return

    const rows = [...this.rowsTarget.querySelectorAll(".color-row")]
    if (!rows.length) return

    let invalid = false

    rows.forEach(row => {
      const input = row.querySelector(".additive-amount")
      const amount = Number(input.value.replace(",", "."))

      if (!Number.isFinite(amount) || amount <= 0) {
        input.classList.add("color-error")
        invalid = true
      }
    })

    if (invalid) return

    if (this.editingId) {
      this.updateIngredient(rows[0])
    } else {
      const stepId = this.currentStep.dataset.stepId

      rows.forEach(row => this.createIngredient(row, stepId))
    }

    this.closeModal()

    requestAnimationFrame(() => {
      window.dispatchEvent(new CustomEvent("formula:changed"))
      window.dispatchEvent(new CustomEvent("formula:firstStepFilled"))
    })
  }

  updateIngredient(row) {
    const hidden = this.findIngredient(this.editingId)
    const display = [...this.currentStep.querySelectorAll(".additive-row-display")].find(element => element.dataset.id === String(this.editingId))

    if (!hidden || !display) return

    this.fillHidden(hidden, row)
    this.fillDisplay(display, row)
  }

  createIngredient(row, stepId) {
    const template = this.currentStep.querySelector("[data-formula-target='ingredientTemplate']")
    const hiddenContainer = this.currentStep.querySelector("[data-formula-target='colorsList']")
    const displayContainer = this.currentStep.querySelector("[data-additive-list]")

    if (!template || !hiddenContainer || !displayContainer) return

    const uid = `new_${Date.now()}_${Math.random().toString(36).slice(2)}`
    const html = template.innerHTML.replace(/NEW_ID/g, uid).replace(/STEP_ID/g, stepId)
    const wrapper = document.createElement("div")
    wrapper.innerHTML = html

    const hidden = wrapper.querySelector(".ingredient-fields")
    if (!hidden) return

    hidden.dataset.id = uid
    this.fillHidden(hidden, row)
    hiddenContainer.appendChild(hidden)

    const display = document.createElement("div")
    display.className = "color-row-display additive-row-display"
    display.dataset.id = uid

    display.innerHTML = `
      <div class="color-left">
        <span class="shade"></span>
        <span class="brand"></span>
      </div>

      <div class="color-right">
        <span class="amount"></span>

        <div class="color-actions">
          <button type="button" class="edit-btn"
                  data-action="click->formula#editAdditive">
            <img class="edit-icon" alt="Edit">
          </button>

          <button type="button" class="delete-btn"
                  data-action="click->formula#removeAdditive">
            <img class="delete-icon" alt="Delete">
          </button>
        </div>
      </div>
    `

    this.fillDisplay(display, row)

    display.querySelector(".edit-icon").src = this.editIconValue
    display.querySelector(".delete-icon").src = this.deleteIconValue

    displayContainer.appendChild(display)
  }

  fillHidden(hidden, row) {
    hidden.dataset.unit = row.dataset.unit || "g"

    const values = {
      brand: row.dataset.brand,
      shade: row.querySelector(".additive-name").value.trim(),
      amount: row.querySelector(".additive-amount").value.replace(",", "."),
      formula_product_id: row.dataset.productId,
      price: row.dataset.price,
      kind: "additive"
    }

    Object.entries(values).forEach(([field, value]) => {
      const input = hidden.querySelector(`[data-field="${field}"]`)
      if (input) input.value = value
    })
  }

  fillDisplay(display, row) {
    display.querySelector(".brand").textContent = row.dataset.brand
    display.querySelector(".shade").textContent = row.querySelector(".additive-name").value.trim()
    display.querySelector(".amount").textContent = `${row.querySelector(".additive-amount").value.replace(",", ".")}${row.dataset.unit || "g"}`
  }

  stop(event) {
    event.stopPropagation()
  }
}

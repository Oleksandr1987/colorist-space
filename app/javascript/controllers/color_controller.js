// app/javascript/controllers/color_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "rows", "list", "productSelect", "newColorForm", "newBrand", "newName", "newUnit", "newPrice"]

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

    this.productSelectTarget.selectedIndex = 0
    this.rowsTarget.innerHTML = ""
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
    const option = this.productSelectTarget.selectedOptions[0]

    if (!option || !option.value) {
      return
    }

    const shade = option.dataset.name
    const brand = option.dataset.brand
    const productId = option.value
    const price = option.dataset.price || 0

    const row = document.createElement("div")

    row.className = "color-row"

    row.dataset.productId = productId
    row.dataset.price = price

    row.innerHTML = `
      <input type="text"
            value="${shade}"
            readonly>

      <input type="text"
            value="${brand}"
            readonly>

      <input type="text"
            placeholder="Amount">

      <button type="button"
              class="color-remove">
        ×
      </button>
    `

    const removeButton = row.querySelector(".color-remove")

    removeButton.onclick = () => row.remove()

    const amountInput = row.querySelectorAll("input")[2]

    amountInput.addEventListener("input", () => {
      let value = amountInput.value

      value = value.replace(/[^0-9.,]/g, "")

      amountInput.value = value

      amountInput.classList.remove("color-error")
    })

    this.rowsContainer.appendChild(row)

    this.productSelectTarget.selectedIndex = 0
  }

  showNewColorForm() {
    this.newColorFormTarget.classList.toggle("hidden")
  }

  async createColor() {
    const brand =
      this.newBrandTarget.value.trim()

    const name =
      this.newNameTarget.value.trim()

    if (!brand || !name) return

    const token =
      document.querySelector(
        "meta[name='csrf-token']"
      ).content

    const response = await fetch(
      "/formula_products",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": token,
          "Accept": "application/json"
        },
        body: JSON.stringify({
          formula_product: {
            category: "color",
            brand: brand,
            name: name,
            unit: this.newUnitTarget.value,
            price_per_unit: parseFloat(
              this.newPriceTarget.value || 0
            )
          }
        })
      }
    )

    if (!response.ok) return

    const color = await response.json()

    const option =
      document.createElement("option")

    option.value = color.id
    option.dataset.brand = color.brand
    option.dataset.name = color.name

    option.textContent =
      `${color.brand} - ${color.name}`

    this.productSelectTarget.appendChild(option)

    this.productSelectTarget.value = color.id

    this.newBrandTarget.value = ""
    this.newNameTarget.value = ""
    this.newPriceTarget.value = ""
    this.newUnitTarget.value = "g"

    this.newColorFormTarget.classList.add("hidden")
  }

  hideNewColorForm() {
    this.newColorFormTarget.classList.add("hidden")
  }

  save() {
    if (!this.currentStep) return

    const rows = this.rowsTarget.querySelectorAll(".color-row")

    const stepId = this.currentStep.dataset.stepId

    let hasErrors = false

    rows.forEach(row => {
      const amountInput =
        row.querySelectorAll("input")[2]

      if (!amountInput.value.trim()) {
        amountInput.classList.add("color-error")
        amountInput.focus()
        hasErrors = true
      }
    })

    if (hasErrors) {
      return
    }

    rows.forEach(row => {
      const [shadeInput, brandInput, amountInput] = row.querySelectorAll("input")

      let shade = shadeInput.value.trim()
      let brand = brandInput.value.trim()
      let amount = amountInput.value.trim()

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

      hidden.querySelector("[data-field='shade']").value = shade
      hidden.querySelector("[data-field='brand']").value = brand
      hidden.querySelector("[data-field='amount']").value = amount
      hidden.querySelector("[data-field='formula_product_id']").value = row.dataset.productId
      hidden.querySelector("[data-field='price']").value = row.dataset.price

      const hiddenContainer = this.currentStep.querySelector(
        "[data-formula-target='colorsList']"
      )

      hiddenContainer.appendChild(hidden)

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
      const displayContainer = this.currentStep.querySelector(
        "[data-color-target='list']"
      )

      displayContainer.appendChild(display)
    })

    this.rowsTarget.innerHTML = ""
    this.closeModal()

    requestAnimationFrame(() => {
      window.dispatchEvent(
        new CustomEvent("formula:colorAmountChanged", {
          detail: {
            total: this.calculateTotalAmount(),
            stepId: this.currentStep.dataset.stepId
          }
        })
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

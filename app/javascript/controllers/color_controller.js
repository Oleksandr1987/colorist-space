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

    // remove
    row.querySelector(".color-remove").onclick = () => row.remove()

    // amount validation
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

      const step = this.currentStep
      const uid = Math.random().toString(36).slice(2)
      // UI
      const display = document.createElement("div")
      display.className = "color-row-display"
      display.dataset.uid = uid

      display.innerHTML = `
        <div class="color-left">
          <span class="shade">${shade}</span>
          <span class="brand">${brand}</span>
        </div>

        <div class="color-right">
          <span class="amount">${amount}g</span>
          <button type="button" class="remove">×</button>
        </div>
      `

      // display.querySelector(".remove").onclick = () => display.remove()
      display.querySelector(".remove").setAttribute(
        "data-action",
        "click->formula#removeColor"
      )

      step.querySelector("[data-color-target='list']").appendChild(display)

      this.addHiddenIngredient(step, shade, brand, amount, uid)
    })

    const total = this.calculateTotalAmount()

    window.dispatchEvent(
      new CustomEvent("formula:colorAmountChanged", {
        detail: { total: total }
      })
    )

    this.rowsTarget.innerHTML = ""
    this.closeModal()
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

  addHiddenIngredient(step, shade, brand, amount, uid) {
    const list = step.querySelector("[data-formula-target='colorsList']")
    const prototype = list.dataset.prototype

    if (!prototype) return

    let html = prototype

    html = html.replace(/NEW_RECORD/g, () => {
      return Math.random().toString(36).slice(2)
    })

    const wrapper = document.createElement("div")
    wrapper.innerHTML = html

    const el = wrapper.firstElementChild
    el.dataset.id = uid

    el.querySelector("[name*='[shade]']").value = shade
    el.querySelector("[name*='[brand]']").value = brand
    el.querySelector("[name*='[amount]']").value = amount

    list.appendChild(el)
  }
}

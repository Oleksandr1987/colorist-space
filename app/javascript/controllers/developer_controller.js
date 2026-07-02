// app/javascript/controllers/developer_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "modal", "input", "display",
    "serviceSelect",
    "saveBtn",
    "amountInput",
    "customInput",
    "customRatio"
  ]

  connect() {
    this.selectedServiceId = null
    this.selectedRatio = null
    this.colorAmount = 0
    this.manualOverride = false

    this.initializeState()

    this.handleEsc = this.handleEsc.bind(this)
    document.addEventListener("keydown", this.handleEsc)

    this.updateColorAmount = this.updateColorAmount.bind(this)
    this.recalculateFromColors = this.recalculateFromColors.bind(this)
    window.addEventListener(
      "formula:colorAmountChanged",
      this.recalculateFromColors
    )
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleEsc)
    window.removeEventListener(
      "formula:colorAmountChanged",
      this.recalculateFromColors
    )
  }

  // ---------------- ESC ----------------
  handleEsc(e) {
    if (e.key === "Escape") {
      this.closeModal()
    }
  }

  // ---------------- INIT ----------------
  initializeState() {
    if (!this.hasInputTarget) return

    let hasValue = false

    try {
      const parsed = JSON.parse(this.inputTarget.value || "{}")
      hasValue = !!parsed.formula_product_id
    } catch {
      hasValue = false
    }

    const addBtn = this.element.querySelector(".add-dev-btn")

    if (addBtn) {
      addBtn.style.display = hasValue ? "none" : "inline-flex"
    }
  }

  // ---------------- MODAL ----------------
  openModal(isEdit = false) {
    if (this.hasModalTarget) {
      this.modalTarget.classList.remove("hidden")
    }

    const step = this.element.closest(".formula-card")

    let total = 0
    step.querySelectorAll("[name*='[amount]']").forEach(input => {
      const val = parseFloat(input.value)
      if (!isNaN(val)) total += val
    })

    this.colorAmount = total

    if (isEdit && this.inputTarget.value) {
      const data = JSON.parse(this.inputTarget.value)

      this.selectedServiceId = data.formula_product_id
      this.selectedPrice = parseFloat(data.price || 0)
      this.selectedRatio = data.ratio

      this.serviceSelectTarget.value = data.formula_product_id

      this.highlightRatio(data.ratio)

      this.amountInputTarget.value = data.amount || 0
    }

    this.calculateAmount()
  }

  edit() {
    this.openModal(true)
  }

  closeModal() {
    if (this.hasModalTarget) {
      this.modalTarget.classList.add("hidden")
    }

    this.selectedServiceId = null
    this.selectedRatio = null

    if (this.hasSaveBtnTarget) {
      this.saveBtnTarget.disabled = true
    }

    this.initializeState()
  }

  // ---------------- SELECT SERVICE ----------------
  selectService() {
    const option = this.serviceSelectTarget.selectedOptions[0]

    if (!option || !option.value) return

    this.selectedServiceId = option.value
    this.selectedPrice = parseFloat(option.dataset.price || 0)

    this.enableSave()
  }

  // ---------------- RATIO ----------------
  setRatio(e) {
    this.selectedRatio = e.currentTarget.dataset.ratio
    this.manualOverride = false

    e.currentTarget.parentElement
      .querySelectorAll("button")
      .forEach(b => b.classList.remove("active"))

    e.currentTarget.classList.add("active")

    if (this.hasCustomRatioTarget) {
      this.customRatioTarget.classList.remove("active")
    }

    this.calculateAmount()
    this.enableSave()
  }

  addCustom() {
    if (!this.hasCustomInputTarget) return

    let value = this.customInputTarget.value.trim()

    if (!value) return

    value = value.replace(",", ".")
    value = value.replace("1:", "")

    const number = parseFloat(value)

    if (isNaN(number) || number <= 0) {
      alert("Enter positive ratio")
      return
    }

    this.selectedRatio = `1:${number}`

    this.element
      .querySelectorAll(".dev-ratio button")
      .forEach(button => button.classList.remove("active"))

    this.customInputTarget.value = this.selectedRatio

    this.calculateAmount()

    this.highlightCustomRatio()

    this.enableSave()
  }

  normalizeCustomRatio() {
    if (!this.hasCustomInputTarget) return

    let value = this.customInputTarget.value.trim()

    value = value.replace(",", ".")
    value = value.replace(/[^0-9:.]/g, "")

    if (!value.startsWith("1:")) {
      value = "1:" + value.replace("1:", "").replace(":", "")
    }

    this.customInputTarget.value = value

    this.element
      .querySelectorAll(".dev-ratio button")
      .forEach(button => button.classList.remove("active"))

    this.highlightCustomRatio()
  }

  updateRatioPreview() {
    this.element
      .querySelectorAll(".dev-ratio button")
      .forEach(button => button.classList.remove("active"))

    this.customInputTarget.value = this.selectedRatio
  }

  highlightCustomRatio() {
    if (!this.hasCustomRatioTarget) return

    this.element
      .querySelectorAll(".dev-ratio > button")
      .forEach(button => button.classList.remove("active"))

    this.customRatioTarget.classList.add("active")
  }

  // ---------------- ENABLE SAVE ----------------
  enableSave() {
    if (!this.hasSaveBtnTarget) return

    const canSave =
      this.selectedServiceId &&
      this.selectedRatio

    this.saveBtnTarget.disabled = !canSave
  }

  // ---------------- CALCULATE ----------------
  updateColorAmount(event) {
    const stepId = this.element.dataset.stepId
    if (event.detail.stepId !== stepId) return

    this.colorAmount = event.detail.total || 0

    if (!this.manualOverride) {
      this.calculateAmount()
    }
    const amount = this.calculateAmount()

    if (!this.selectedServiceId) return

    const result = {
      formula_product_id: this.selectedServiceId,
      price: this.selectedPrice,
      ratio: this.selectedRatio,
      amount: amount
    }

    this.inputTarget.value = JSON.stringify(result)

    if (this.hasDisplayTarget) {
      this.renderDisplay(this.selectedServiceId, this.selectedRatio, amount)
    }
  }

  calculateAmount() {
    if (this.manualOverride) {
      return parseFloat(this.amountInputTarget.value || 0)
    }

    if (!this.selectedRatio) {
      this.amountInputTarget.value = 0
      return 0
    }

    const ratio = parseFloat(this.selectedRatio.split(":")[1])

    const result = Math.round(this.colorAmount * ratio)

    this.amountInputTarget.value = result

    return result
  }

  manualAmountChanged() {
    this.manualOverride = true

    let amount = parseFloat(
      this.amountInputTarget.value.replace(",", ".")
    )

    if (isNaN(amount)) amount = 0

    const ratio = this.colorAmount > 0
      ? (amount / this.colorAmount).toFixed(2)
      : 0

    this.selectedRatio = `1:${ratio}`

    this.updateRatioPreview()
    this.highlightCustomRatio()
  }

  // ---------------- DISPLAY ----------------
  renderDisplay(serviceId, ratio, amount) {
    const option = this.serviceSelectTarget.querySelector(
      `option[value='${serviceId}']`
    )

    const name = option ? option.textContent.split("(")[0].trim() : "Unknown"

    this.displayTarget.innerHTML = `
      <div class="dev-row-display">

        <div class="dev-left">
          <span class="dev-name">${name}</span>
          ${ratio ? `<span class="dev-separator">|</span><span class="dev-ratio">${ratio}</span>` : ""}
        </div>

        <div class="dev-right">
          ${amount ? `<span class="dev-amount">${amount}g</span>` : ""}
          <button type="button" class="remove" data-action="click->developer#remove">×</button>
        </div>

      </div>
    `
  } // ---------------- TODO: Add png

  // ---------------- SAVE ----------------
  save() {

    console.log("SAVE", {
      serviceId: this.selectedServiceId,
      ratio: this.selectedRatio,
      price: this.selectedPrice
    })
    if (!this.selectedServiceId) return

    const amount = parseFloat(
      this.amountInputTarget.value || 0
    )

    const result = {
      formula_product_id: this.selectedServiceId,
      price: this.selectedPrice,
      ratio: this.selectedRatio,
      amount: amount
    }

    this.inputTarget.value = JSON.stringify(result)

    if (this.hasDisplayTarget) {
      this.renderDisplay(this.selectedServiceId, this.selectedRatio, amount)
    }

    const addBtn = this.element.querySelector(".add-dev-btn")
    if (addBtn) addBtn.style.display = "none"

    window.dispatchEvent(new CustomEvent("services:changed"))
    window.dispatchEvent(new CustomEvent("formula:changed"))

    this.closeModal()
  }

  // ---------------- REMOVE ----------------
  remove() {
    if (this.hasInputTarget) {
      this.inputTarget.value = ""
    }

    this.manualOverride = false

    if (this.hasDisplayTarget) {
      this.displayTarget.innerHTML = ""
    }

    const addBtn = this.element.querySelector(".add-dev-btn")
    if (addBtn) addBtn.style.display = "inline-flex"

    this.selectedServiceId = null
    this.selectedRatio = null

    if (this.hasInputTarget) {
      this.inputTarget.value = ""
    }

    const step = this.element.closest(".formula-card")

    if (step) {
      window.dispatchEvent(
        new CustomEvent("formula:colorAmountChanged", {
          detail: {
            total: 0,
            stepId: step.dataset.stepId
          }
        })
      )
    }

    window.dispatchEvent(new CustomEvent("formula:changed"))
  }

  recalculateFromColors(event) {
    if (!this.hasInputTarget) return
    if (!this.inputTarget.value) return

    let data

    try {
      data = JSON.parse(this.inputTarget.value)
    } catch {
      return
    }

    if (!data.ratio) return

    const stepId = this.element.dataset.stepId

    if (event.detail.stepId !== stepId) return

    this.colorAmount = event.detail.total || 0

    this.selectedServiceId = data.formula_product_id
    this.selectedPrice = parseFloat(data.price || 0)
    this.selectedRatio = data.ratio

    let amount

    if (this.manualOverride) {
      amount = parseFloat(this.amountInputTarget.value || 0)
    } else {
      amount = this.calculateAmount()
    }

    const updated = {
      formula_product_id: this.selectedServiceId,
      price: this.selectedPrice,
      ratio: this.selectedRatio,
      amount: amount
    }

    this.inputTarget.value = JSON.stringify(updated)

    if (this.hasDisplayTarget) {
      this.renderDisplay(
        this.selectedServiceId,
        this.selectedRatio,
        amount
      )
    }

    window.dispatchEvent(new CustomEvent("formula:changed"))
  }

  // ---------------- OVERLAY ----------------
  closeOnOverlay(event) {
    if (event.target === this.modalTarget) {
      this.closeModal()
    }
  }

  stopPropagation(event) {
    event.stopPropagation()
  }

  highlightRatio(ratio) {
    this.element
      .querySelectorAll(".dev-ratio button")
      .forEach(button => {
        button.classList.toggle(
          "active",
          button.dataset.ratio === ratio
        )
      })
  }
}

// app/javascript/controllers/developer_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "modal", "input", "display",
    "serviceSelect",
    "newName",
    "newPrice",
    "saveBtn",
    "amountDisplay",
    "customInput"
  ]

  connect() {
    this.selectedServiceId = null
    this.selectedRatio = null
    this.colorAmount = 0

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

    const hasValue = this.inputTarget.value && this.inputTarget.value.length > 0

    const addBtn = this.element.querySelector(".add-dev-btn")

    if (addBtn) {
      addBtn.style.display = hasValue ? "none" : "inline-flex"
    }
  }

  // ---------------- MODAL ----------------
  openModal() {
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
    this.calculateAmount()
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

    e.currentTarget.parentElement
      .querySelectorAll("button")
      .forEach(b => b.classList.remove("active"))

    e.currentTarget.classList.add("active")

    this.calculateAmount()
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
  }

  // ---------------- ENABLE SAVE ----------------
  enableSave() {
    if (this.hasSaveBtnTarget) {
      this.saveBtnTarget.disabled = false
    }
  }

  // ---------------- CALCULATE ----------------
  updateColorAmount(event) {
    const stepId = this.element.dataset.stepId
    if (event.detail.stepId !== stepId) return

    this.colorAmount = event.detail.total || 0

    const amount = this.calculateAmount()

    if (!this.selectedServiceId) return

    const result = {
      service_id: this.selectedServiceId,
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
    if (!this.selectedRatio) {
      if (this.hasAmountDisplayTarget) {
        this.amountDisplayTarget.textContent = "0g"
      }
      return 0
    }

    const ratio = parseFloat(this.selectedRatio.split(":")[1])
    const result = Math.round(this.colorAmount * ratio)

    if (this.hasAmountDisplayTarget) {
      this.amountDisplayTarget.textContent = `${result}g`
    }

    return result
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
  }

  // ---------------- SAVE ----------------
  save() {
    if (!this.selectedServiceId) return

    const amount = this.calculateAmount()

    const result = {
      service_id: this.selectedServiceId,
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

    if (this.hasDisplayTarget) {
      this.displayTarget.innerHTML = ""
    }

    const addBtn = this.element.querySelector(".add-dev-btn")
    if (addBtn) addBtn.style.display = "inline-flex"

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

    this.selectedServiceId = data.service_id
    this.selectedPrice = parseFloat(data.price || 0)
    this.selectedRatio = data.ratio

    const amount = this.calculateAmount()

    const updated = {
      service_id: this.selectedServiceId,
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

  // ---------------- CREATE PREPARATION ----------------
  createPreparation() {
    const name = this.newNameTarget.value.trim()
    const price = parseFloat(this.newPriceTarget.value)

    if (!name || isNaN(price)) {
      alert("Fill name and price")
      return
    }

    fetch("/services/create_preparation", {
      method: "POST",
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
        "Content-Type": "application/json",
        "Accept": "application/json"
      },
      body: JSON.stringify({
        service: {
          subtype: name,
          price: price,
          service_type: "preparation"
        }
      })
    })
      .then(r => r.json())
      .then(data => {
        const option = document.createElement("option")
        option.value = data.id
        option.textContent = `${data.subtype} (${data.price} ₴)`
        option.dataset.price = data.price

        this.serviceSelectTarget.appendChild(option)
        this.serviceSelectTarget.value = data.id

        this.selectService()

        this.newNameTarget.value = ""
        this.newPriceTarget.value = ""
      })
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
}

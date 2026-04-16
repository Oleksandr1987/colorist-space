// app/javascript/controllers/developer_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "modal", "input", "display",
    "percentGroup", "volGroup",
    "percentBtn", "volBtn",
    "saveBtn", "customInput",
    "amount", "amountDisplay"
  ]

  connect() {
    this.mode = "percent"
    this.selectedValue = null
    this.selectedRatio = null
    this.colorAmount = 0
    this.initializeState()

    this.handleEsc = this.handleEsc.bind(this)
    document.addEventListener("keydown", this.handleEsc)

    this.updateColorAmount = this.updateColorAmount.bind(this)
    window.addEventListener(
      "formula:colorAmountChanged",
      this.updateColorAmount
    )

    if (this.hasCustomInputTarget) {
      this.customInputTarget.addEventListener("input", () => {
        let val = this.customInputTarget.value
        val = val.replace(/[^0-9.,]/g, "")
        val = val.replace("-", "")
        this.customInputTarget.value = val
      })
    }
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleEsc)
    window.removeEventListener(
      "formula:colorAmountChanged",
      this.updateColorAmount
    )
  }

  handleEsc(e) {
    if (e.key === "Escape") {
      this.closeModal()
    }
  }

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

    this.selectedValue = null
    this.selectedRatio = null

    if (this.hasSaveBtnTarget) {
      this.saveBtnTarget.disabled = true
    }

    this.element.querySelectorAll(".dev-group button")
      .forEach(b => b.classList.remove("active"))
  }

  // ---------------- SWITCH ----------------
  setPercent() {
    this.mode = "percent"

    if (this.hasPercentGroupTarget)
      this.percentGroupTarget.classList.remove("hidden")

    if (this.hasVolGroupTarget)
      this.volGroupTarget.classList.add("hidden")

    this.percentBtnTarget?.classList.add("active")
    this.volBtnTarget?.classList.remove("active")
  }

  setVol() {
    this.mode = "vol"

    if (this.hasVolGroupTarget)
      this.volGroupTarget.classList.remove("hidden")

    if (this.hasPercentGroupTarget)
      this.percentGroupTarget.classList.add("hidden")

    this.volBtnTarget?.classList.add("active")
    this.percentBtnTarget?.classList.remove("active")
  }

  // ---------------- SELECT ----------------
  select(e) {
    this.selectedValue = e.currentTarget.dataset.value
    this.enableSave()

    e.currentTarget
      .closest(".dev-group")
      .querySelectorAll("button")
      .forEach(b => b.classList.remove("active"))

    e.currentTarget.classList.add("active")
  }

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

    let val = this.customInputTarget.value.trim()
    if (!val) return

    val = val.replace(",", ".")
    const number = parseFloat(val)

    if (isNaN(number) || number <= 0) {
      alert("Enter positive number")
      return
    }

    const formatted =
      this.mode === "percent"
        ? `${number}%`
        : `${number}vol.`

    this.selectedValue = formatted

    this.highlightCustomValue()
    this.enableSave()

    this.customInputTarget.value = ""
  }

  highlightCustomValue() {
    this.element.querySelectorAll(".dev-group button")
      .forEach(b => b.classList.remove("active"))
  }

  enableSave() {
    if (this.hasSaveBtnTarget) {
      this.saveBtnTarget.disabled = false
    }
  }

  // ---------------- CALC ----------------
  updateColorAmount(event) {
    const stepId = this.element.dataset.stepId

    if (event.detail.stepId !== stepId) return

    this.colorAmount = event.detail.total || 0

    this.calculateAmount()

    if (this.selectedRatio) {
      const amount = this.calculateAmount()

      const result = [
        this.selectedValue,
        this.selectedRatio,
        amount
      ].filter(Boolean).join("|")

      if (this.hasInputTarget) {
        this.inputTarget.value = result
      }

      if (this.hasDisplayTarget) {
        this.renderDisplay(this.selectedValue, this.selectedRatio, amount)
      }
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

  renderDisplay(value, ratio, amount) {
    this.displayTarget.innerHTML = `
      <div class="dev-row-display">

        <div class="dev-left">
          <span class="dev-percent">${value}</span>
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
    let value = this.selectedValue || ""
    let ratio = this.selectedRatio || ""

    const amount = this.calculateAmount()

    const result = [value, ratio, amount].filter(Boolean).join("|")

    if (this.hasInputTarget) {
      this.inputTarget.value = result
    }

    if (this.hasDisplayTarget) {
      this.renderDisplay(value, ratio, amount)
    }

    const addBtn = this.element.querySelector(".add-dev-btn")
    if (addBtn) addBtn.style.display = "none"

    this.closeModal()
  }

  closeOnOverlay(event) {
    if (event.target === this.modalTarget) {
      this.closeModal()
    }
  }

  stopPropagation(event) {
    event.stopPropagation()
  }

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
  }
}

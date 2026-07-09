// app/javascript/controllers/developer_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "modal",
    "input",
    "list",
    "itemTemplate",
    "brandSelect",
    "serviceSelect",
    "saveBtn",
    "amountInput",
    "customInput",
    "customRatio"
  ]

  connect() {
    this.selectedServiceId = null
    this.selectedPrice = null
    this.selectedRatio = null

    this.editIndex = null
    this.colorAmount = 0
    this.manualOverride = false

    this.serviceOptions = this.hasServiceSelectTarget
      ? Array.from(this.serviceSelectTarget.options)
      : []

    this.loadOxidants()
    this.renderList()

    this.handleEsc = this.handleEsc.bind(this)
    document.addEventListener("keydown", this.handleEsc)

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

  // ---------------- MODAL ----------------
  openModal(isEdit = false) {
    if (this.hasModalTarget) {
      this.modalTarget.classList.remove("hidden")
    }

    const step = this.element.closest(".formula-card")

    let total = 0

    step.querySelectorAll("[name*='[amount]']").forEach(input => {
      const value = parseFloat(input.value)

      if (!isNaN(value)) {
        total += value
      }
    })

    this.colorAmount = total

    this.selectedServiceId = null
    this.selectedPrice = null
    this.selectedRatio = null
    this.manualOverride = false

    this.amountInputTarget.value = 0

    if (this.hasBrandSelectTarget) {
      this.brandSelectTarget.value = ""
    }

    this.serviceSelectTarget.innerHTML = ""

    this.serviceOptions.forEach(option => {
      this.serviceSelectTarget.appendChild(
        option.cloneNode(true)
      )
    })

    if (isEdit && this.editIndex !== null) {

      const item = this.oxidants[this.editIndex]

      if (item) {

        this.selectedServiceId = item.formula_product_id
        this.selectedPrice = item.price
        this.selectedRatio = item.ratio

        this.amountInputTarget.value = item.amount

        const originalOption = this.serviceOptions.find(option =>
          String(option.value) ===
          String(item.formula_product_id)
        )

        if (originalOption && this.hasBrandSelectTarget) {

          this.brandSelectTarget.value =
            originalOption.dataset.brand

          this.selectBrand()

          this.serviceSelectTarget.value =
            item.formula_product_id
        }

        this.highlightRatio(item.ratio)
      }

    } else {

      this.calculateAmount()

    }

    this.enableSave()
  }

  edit(event) {
    this.editIndex = Number(
      event.currentTarget.dataset.index
    )

    this.openModal(true)
  }

  closeModal() {
    if (this.hasModalTarget) {
      this.modalTarget.classList.add("hidden")
    }

    this.selectedServiceId = null
    this.selectedPrice = null
    this.selectedRatio = null

    this.manualOverride = false
    this.editIndex = null

    this.amountInputTarget.value = 0

    if (this.hasBrandSelectTarget) {
      this.brandSelectTarget.value = ""
    }

    this.serviceSelectTarget.innerHTML = ""

    this.serviceOptions.forEach(option => {
      this.serviceSelectTarget.appendChild(
        option.cloneNode(true)
      )
    })

    this.serviceSelectTarget.value = ""

    this.element
      .querySelectorAll(".dev-ratio button")
      .forEach(button => button.classList.remove("active"))

    if (this.hasCustomRatioTarget) {
      this.customRatioTarget.classList.remove("active")
    }

    if (this.hasCustomInputTarget) {
      this.customInputTarget.value = "1:"
    }

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

  selectBrand() {
    const brand = this.brandSelectTarget.value

    this.serviceSelectTarget.innerHTML = ""

    const placeholder = document.createElement("option")
    placeholder.value = ""
    placeholder.textContent = "Choose..."
    this.serviceSelectTarget.appendChild(placeholder)

    this.serviceOptions.forEach(option => {
      if (!option.value) return

      if (option.dataset.brand === brand) {
        this.serviceSelectTarget.appendChild(
          option.cloneNode(true)
        )
      }
    })

    this.selectedServiceId = null
    this.selectedPrice = null
    this.serviceSelectTarget.value = ""
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

  loadOxidants() {
    this.oxidants = []

    if (!this.hasInputTarget) return

    const value = this.inputTarget.value

    if (!value) return

    try {
      const parsed = JSON.parse(value)

      if (Array.isArray(parsed)) {
        this.oxidants = parsed
      } else if (parsed?.formula_product_id) {
        this.oxidants = [parsed]
      }

    } catch {
      this.oxidants = []
    }
  }

  saveOxidants() {
    if (!this.hasInputTarget) return

    this.inputTarget.value =
      this.oxidants.length
        ? JSON.stringify(this.oxidants)
        : ""

    this.renderList()
  }

  // ---------------- ENABLE SAVE ----------------
  enableSave() {
    if (!this.hasSaveBtnTarget) return

    const canSave = this.selectedServiceId && this.selectedRatio

    this.saveBtnTarget.disabled = !canSave
  }

  // ---------------- CALCULATE ----------------
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

    let amount = parseFloat(this.amountInputTarget.value.replace(",", "."))

    if (isNaN(amount)) amount = 0

    const ratio = this.colorAmount > 0
      ? (amount / this.colorAmount).toFixed(2)
      : 0

    this.selectedRatio = `1:${ratio}`

    this.updateRatioPreview()
    this.highlightCustomRatio()
  }

  // ---------------- DISPLAY ----------------
  renderList() {
    if (!this.hasListTarget) return

    this.listTarget.innerHTML = ""

    this.oxidants.forEach((oxidant, index) => {

      const row =
        this.itemTemplateTarget.content
          .firstElementChild
          .cloneNode(true)

      const option =
        this.serviceOptions.find(option =>
          String(option.value) ===
          String(oxidant.formula_product_id)
        )

      const brand = option?.dataset.brand || ""
      const name = option?.textContent.trim() || ""

      row.querySelector(".dev-name").textContent =
        [brand, name].filter(Boolean).join(" ")

      row.querySelector(".dev-ratio").textContent = oxidant.ratio

      row.querySelector(".dev-amount").textContent = `${oxidant.amount}g`

      const edit = row.querySelector(".edit-item")

      edit.dataset.index = index
      edit.dataset.action = "click->developer#edit"

      const remove = row.querySelector(".delete-item")

      remove.dataset.index = index
      remove.dataset.action = "click->developer#remove"

      this.listTarget.appendChild(row)
    })
  }

  // ---------------- SAVE ----------------
  save() {
    if (!this.selectedServiceId) return

    const amount = parseFloat(
      this.amountInputTarget.value || 0
    )

    const item = {
      formula_product_id: this.selectedServiceId,
      price: this.selectedPrice,
      ratio: this.selectedRatio,
      amount: amount
    }

    if (this.editIndex === null) {
      this.oxidants.push(item)
    } else {
      this.oxidants[this.editIndex] = item
    }

    this.saveOxidants()

    this.editIndex = null

    window.dispatchEvent(new CustomEvent("services:changed"))
    window.dispatchEvent(new CustomEvent("formula:changed"))

    this.closeModal()
  }

  // ---------------- REMOVE ----------------
  remove(event) {
    const index = Number(event.currentTarget.dataset.index)

    this.oxidants.splice(index, 1)
    this.saveOxidants()

    window.dispatchEvent(new CustomEvent("services:changed"))
    window.dispatchEvent(new CustomEvent("formula:changed"))
  }

  recalculateFromColors(event) {
    const stepId = this.element.dataset.stepId

    if (event.detail.stepId !== stepId) return

    this.colorAmount = event.detail.total || 0

    if (this.hasModalTarget &&
        !this.modalTarget.classList.contains("hidden")) {
      this.calculateAmount()
    }
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

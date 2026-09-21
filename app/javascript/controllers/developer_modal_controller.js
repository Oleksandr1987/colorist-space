// app/javascript/controllers/developer_modal_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "brandSelect", "serviceSelect", "saveBtn", "amountInput", "customInput", "customRatio", "customToggle"]

  connect() {
    this.sourceController = null
    this.editIndex = null
    this.selectedServiceId = null
    this.selectedPrice = null
    this.selectedRatio = null
    this.colorAmount = 0
    this.manualOverride = false
    this.serviceOptions = this.hasServiceSelectTarget ? Array.from(this.serviceSelectTarget.options) : []
    this.productLookup = new Map()
    this.serviceOptions.forEach(option => {
      if (!option.value) return

      this.productLookup.set(String(option.value), {
        brand: option.dataset.brand || "", name: option.dataset.name || option.textContent.trim()
      })
    })

    this.handleOpen = this.handleOpen.bind(this)
    this.handleEsc = this.handleEsc.bind(this)

    window.addEventListener("developer:open", this.handleOpen)
    document.addEventListener("keydown", this.handleEsc)

    window.dispatchEvent(
      new CustomEvent("developer:products-ready", {
        detail: {
          products: Object.fromEntries(this.productLookup)
        }
      })
    )
  }

  disconnect() {
    window.removeEventListener("developer:open", this.handleOpen)
    document.removeEventListener("keydown", this.handleEsc)
  }

  // OPEN
  handleOpen(event) {
    const { controller, colorAmount, editIndex = null, item = null } = event.detail

    this.sourceController = controller
    this.colorAmount = Number(colorAmount) || 0
    this.editIndex = editIndex
    this.resetForm()
    this.modalTarget.classList.remove("hidden")

    if (item) {
      this.loadItem(item)
    }

    this.enableSave()
  }

  loadItem(item) {
    this.selectedServiceId = String(item.formula_product_id)
    this.selectedPrice = Number(item.price) || 0
    this.selectedRatio = item.ratio

    if (this.hasAmountInputTarget) {
      this.amountInputTarget.value = item.amount ?? 0
    }

    const option = this.serviceOptions.find(option => String(option.value) === String(item.formula_product_id))

    if (option && this.hasBrandSelectTarget) {
      this.brandSelectTarget.value = option.dataset.brand || ""
      this.filterServicesByBrand()

      if (this.hasServiceSelectTarget) {
        this.serviceSelectTarget.value = String(item.formula_product_id)
      }
    }

    this.highlightRatio(item.ratio)
  }

  // CLOSE
  close() {
    this.modalTarget.classList.add("hidden")
    this.resetForm()
    this.sourceController = null
    this.editIndex = null
  }

  closeOnOverlay(event) {
    if (event.target === this.modalTarget) {
      this.close()
    }
  }

  stopPropagation(event) {
    event.stopPropagation()
  }

  handleEsc(event) {
    if (
      event.key === "Escape" && !this.modalTarget.classList.contains("hidden")
    ) {
      this.close()
    }
  }

  // RESET
  resetForm() {
    this.selectedServiceId = null
    this.selectedPrice = null
    this.selectedRatio = null
    this.manualOverride = false

    if (this.hasBrandSelectTarget) {
      this.brandSelectTarget.value = ""
    }

    this.restoreServiceOptions()

    if (this.hasServiceSelectTarget) {
      this.serviceSelectTarget.value = ""
    }

    if (this.hasAmountInputTarget) {
      this.amountInputTarget.value = 0
    }

    this.element
      .querySelectorAll(".dev-ratio button[data-ratio]")
      .forEach(button => { button.classList.remove("active") })

    if (this.hasCustomRatioTarget) {
      this.customRatioTarget.classList.add("hidden")
    }

    if (this.hasCustomToggleTarget) {
      this.customToggleTarget.classList.remove("hidden")
    }

    if (this.hasCustomInputTarget) {
      this.customInputTarget.value = ""
    }

    if (this.hasSaveBtnTarget) {
      this.saveBtnTarget.disabled = true
    }
  }

  restoreServiceOptions() {
    if (!this.hasServiceSelectTarget) return

    this.serviceSelectTarget.innerHTML = ""
    this.serviceOptions.forEach(option => {
      this.serviceSelectTarget.appendChild(option.cloneNode(true))
    })
  }

  // BRAND
  selectBrand() {
    this.filterServicesByBrand()
    this.selectedServiceId = null
    this.selectedPrice = null
    this.enableSave()
  }

  filterServicesByBrand() {
    if (
      !this.hasBrandSelectTarget || !this.hasServiceSelectTarget
    ) {
      return
    }

    const brand = this.brandSelectTarget.value

    this.serviceSelectTarget.innerHTML = ""

    const placeholder = this.serviceOptions.find(option => !option.value)

    if (placeholder) {
      this.serviceSelectTarget.appendChild(placeholder.cloneNode(true))
    }

    this.serviceOptions.forEach(option => {
      if (!option.value) return

      if (option.dataset.brand === brand) {
        this.serviceSelectTarget.appendChild(option.cloneNode(true))
      }
    })

    this.serviceSelectTarget.value = ""
  }

  // OXIDANT
  selectService() {
    if (!this.hasServiceSelectTarget) return

    const option = this.serviceSelectTarget.selectedOptions[0]

    if (!option?.value) {
      this.selectedServiceId = null
      this.selectedPrice = null
      this.enableSave()
      return
    }

    this.selectedServiceId = option.value
    this.selectedPrice = parseFloat(option.dataset.price || 0)
    this.enableSave()
  }

  // RATIO
  setRatio(event) {
    this.hideCustomRatio()

    this.selectedRatio = event.currentTarget.dataset.ratio
    this.manualOverride = false
    this.element
      .querySelectorAll(".dev-ratio button[data-ratio]")
      .forEach(button => {
        button.classList.remove("active")
      })

    event.currentTarget.classList.add("active")

    this.calculateAmount()
    this.enableSave()
  }

  showCustomRatio({ focus = true } = {}) {
    if (!this.hasCustomRatioTarget) return

    this.customRatioTarget.classList.remove("hidden")

    if (this.hasCustomToggleTarget) {
      this.customToggleTarget.classList.add("hidden")
    }

    if (focus && this.hasCustomInputTarget) {
      requestAnimationFrame(() => {
        this.customInputTarget.focus()
      })
    }
  }

  cancelCustomRatio() {
    this.hideCustomRatio()
  }

  addCustom() {
    if (!this.hasCustomInputTarget) return

    const value = this.customInputTarget.value.trim().replace(",", ".")
    const number = parseFloat(value)

    if (isNaN(number) || number <= 0) return

    this.selectedRatio = `1:${number}`
    this.manualOverride = false
    this.element
      .querySelectorAll(".dev-ratio button[data-ratio]")
      .forEach(button => {
        button.classList.remove("active")
      })

    this.calculateAmount()
    this.enableSave()
    this.hideCustomRatio()
  }

  normalizeCustomRatio() {
    if (!this.hasCustomInputTarget) return

    let value = this.customInputTarget.value

    value = value.replace(",", ".")
    value = value.replace(/[^0-9.]/g, "")

    const parts = value.split(".")

    if (parts.length > 2) {
      value = `${parts.shift()}.${parts.join("")}`
    }

    this.customInputTarget.value = value
  }

  hideCustomRatio() {
    if (this.hasCustomRatioTarget) {
      this.customRatioTarget.classList.add("hidden")
    }

    if (this.hasCustomToggleTarget) {
      this.customToggleTarget.classList.remove("hidden")
    }

    if (this.hasCustomInputTarget) {
      this.customInputTarget.value = ""
    }
  }

  highlightRatio(ratio) {
    let found = false

    this.element
      .querySelectorAll(".dev-ratio button[data-ratio]")
      .forEach(button => {
        const active = button.dataset.ratio === ratio

        button.classList.toggle("active", active)

        if (active) {
          found = true
        }
      })

    if (!found && ratio) {
      this.showCustomRatio({ focus: false })

      if (this.hasCustomInputTarget) {
        this.customInputTarget.value =
          ratio.split(":")[1] || ""
      }
    }
  }

  // AMOUNT
  calculateAmount() {
    if (!this.hasAmountInputTarget) return 0

    if (this.manualOverride) {
      return parseFloat(
        this.amountInputTarget.value || 0
      )
    }

    if (!this.selectedRatio) {
      this.amountInputTarget.value = 0
      return 0
    }

    const ratio = parseFloat(this.selectedRatio.split(":")[1])

    if (isNaN(ratio)) {
      this.amountInputTarget.value = 0
      return 0
    }

    const result = Math.round(this.colorAmount * ratio)

    this.amountInputTarget.value = result

    return result
  }

  manualAmountChanged() {
    if (!this.hasAmountInputTarget) return

    this.manualOverride = true

    let amount = parseFloat(this.amountInputTarget.value.replace(",", "."))

    if (isNaN(amount)) {
      amount = 0
    }

    const ratio = this.colorAmount > 0 ? (amount / this.colorAmount).toFixed(2) : 0

    this.selectedRatio = `1:${ratio}`
    this.showCustomRatio({ focus: false })

    if (this.hasCustomInputTarget) {
      this.customInputTarget.value = ratio
    }

    this.enableSave()
  }

  // SAVE
  save() {
    if (
      !this.sourceController || !this.selectedServiceId || !this.selectedRatio
    ) {
      return
    }

    const option = this.hasServiceSelectTarget ? this.serviceSelectTarget.selectedOptions[0] : null
    const amount = parseFloat(this.amountInputTarget.value || 0)
    const item = {
      formula_product_id: this.selectedServiceId,
      brand: option?.dataset.brand || "",
      name: option?.dataset.name || option?.textContent.trim() || "",
      price: this.selectedPrice,
      ratio: this.selectedRatio,
      amount
    }
    this.sourceController.saveFromModal(item, this.editIndex)
    this.close()
  }

  // SAVE BUTTON
  enableSave() {
    if (!this.hasSaveBtnTarget) return

    const canSave = Boolean(this.selectedServiceId) && Boolean(this.selectedRatio)

    this.saveBtnTarget.disabled = !canSave
  }
}

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

    this.handleEsc = this.handleEsc.bind(this)
    document.addEventListener("keydown", this.handleEsc)

    this.updateColorAmount = this.updateColorAmount.bind(this)
    window.addEventListener(
      "formula:colorAmountChanged",
      this.updateColorAmount
    )

    // ✅ SAFE target
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

  // ---------------- MODAL ----------------
  openModal() {
    if (this.hasModalTarget) {
      this.modalTarget.classList.remove("hidden")
    }
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
  // updateColorAmount(event) {
  //   this.colorAmount = event.detail?.total || 0
  //   this.calculateAmount()
  // }
  updateColorAmount(event) {
    this.colorAmount = event.detail?.total || 0

    // 🔥 якщо вже є вибраний developer → перерахувати
    if (this.selectedRatio && this.selectedValue) {
      const amount = this.calculateAmount()

      const result = [
        this.selectedValue,
        this.selectedRatio,
        amount
      ].filter(Boolean).join("|")

      // 👉 hidden sync
      if (this.hasInputTarget) {
        this.inputTarget.value = result
      }

      // 👉 UI sync
      if (this.hasDisplayTarget) {
        this.renderDisplay(this.selectedValue, this.selectedRatio, amount)
      }
    }
  }
  // calculateAmount() {
  //   if (!this.selectedRatio || !this.colorAmount) return
  //   if (!this.hasAmountTarget) return

  //   const ratio = parseFloat(this.selectedRatio.split(":")[1])
  //   const result = Math.round(this.colorAmount * ratio)

  //   this.amountTarget.value = result
  // }

  // ---------------- SAVE ----------------
  // save() {
  //   let result = this.selectedValue || ""

  //   if (this.selectedRatio) {
  //     result += ` | ${this.selectedRatio}`
  //   }

  //   if (this.hasInputTarget) {
  //     this.inputTarget.value = result
  //   }

  //   if (this.hasDisplayTarget) {
  //     this.displayTarget.textContent = result
  //   }

  //   this.closeModal()
  // }
  calculateAmount() {
    if (!this.selectedRatio || !this.colorAmount) return

    const ratio = parseFloat(this.selectedRatio.split(":")[1])
    const result = Math.round(this.colorAmount * ratio)

    // 👉 показ в модалці
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
          <button type="button" class="remove">×</button>
        </div>

      </div>
    `
  }

  // save() {
  //   let value = this.selectedValue || ""
  //   let ratio = this.selectedRatio || ""
  //   let amount = this.amountTarget?.value || ""

  //   // 👉 якщо нема amount — рахуємо
  //   if (!amount && ratio && this.colorAmount) {
  //     const r = parseFloat(ratio.split(":")[1])
  //     amount = Math.round(this.colorAmount * r)
  //   }

  //   // 👉 зберігаємо як structured string
  //   const result = [value, ratio, amount].filter(Boolean).join("|")

  //   // hidden input
  //   if (this.hasInputTarget) {
  //     this.inputTarget.value = result
  //   }

  //   // UI
  //   if (this.hasDisplayTarget) {
  //     this.displayTarget.innerHTML = `
  //       <div class="dev-row-display">

  //         <div class="dev-left">
  //           <span class="dev-percent">${value}</span>
  //           ${ratio ? `<span class="dev-separator">|</span><span class="dev-ratio">${ratio}</span>` : ""}
  //         </div>

  //         <div class="dev-right">
  //           ${amount ? `<span class="dev-amount">${amount}g</span>` : ""}
  //           <button type="button" class="remove">×</button>
  //         </div>

  //       </div>
  //     `
  //   }

  //   this.closeModal()
  // }
  save() {
    let value = this.selectedValue || ""
    let ratio = this.selectedRatio || ""

    // 👉 amount тільки з calculate
    const amount = this.calculateAmount()

    const result = [value, ratio, amount].filter(Boolean).join("|")

    // hidden
    if (this.hasInputTarget) {
      this.inputTarget.value = result
    }

    // UI
    if (this.hasDisplayTarget) {
      this.renderDisplay(value, ratio, amount)
    }

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
}

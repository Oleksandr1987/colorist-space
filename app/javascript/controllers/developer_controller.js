// app/javascript/controllers/developer_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "list", "itemTemplate"]

  connect() {
    this.oxidants = []
    this.loadOxidants()
    this.renderList()
  }

  // OPEN
  openModal(event) {
    event.preventDefault()

    window.dispatchEvent(
      new CustomEvent("developer:open", {
        detail: {
          controller: this,
          stepId: this.element.dataset.stepId,
          colorAmount: this.getColorAmount(),
          oxidants: this.oxidants
        }
      })
    )
  }

  edit(event) {
    event.preventDefault()

    const index = Number(event.currentTarget.dataset.index)
    const item = this.oxidants[index]

    if (!item) return

    window.dispatchEvent(
      new CustomEvent("developer:open", {
        detail: {
          controller: this,
          stepId: this.element.dataset.stepId,
          colorAmount: this.getColorAmount(),
          oxidants: this.oxidants,
          editIndex: index,
          item
        }
      })
    )
  }

  //  COLOR AMOUNT
  getColorAmount() {
    let total = 0

    this.element
      .querySelectorAll(".ingredient-fields")
      .forEach(wrapper => {
        const destroyInput = wrapper.querySelector("[data-field='destroy']")

        if (destroyInput?.value === "1") return

        const amountInput = wrapper.querySelector("[data-field='amount']")
        const value = parseFloat(amountInput?.value || 0)

        if (!isNaN(value)) {
          total += value
        }
      })

    return total
  }

  // LOAD
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

  // SAVE FROM MODAL
  saveFromModal(item, editIndex = null) {
    if (editIndex === null) {
      this.oxidants.push(item)
    } else {
      this.oxidants[editIndex] = item
    }

    this.saveOxidants()

    window.dispatchEvent(new CustomEvent("formula:changed"))
  }

  saveOxidants() {
    if (!this.hasInputTarget) return

    this.inputTarget.value = this.oxidants.length ? JSON.stringify(this.oxidants) : ""
    this.renderList()
  }

  // REMOVE
  remove(event) {
    event.preventDefault()

    const index = Number(event.currentTarget.dataset.index)

    if (
      Number.isNaN(index) ||
      !this.oxidants[index]
    ) {
      return
    }

    this.oxidants.splice(index, 1)
    this.saveOxidants()

    window.dispatchEvent(new CustomEvent("formula:changed"))
  }

  getProductInfo(productId) {
    const modal = document.querySelector('[data-controller~="developer-modal"]')

    if (!modal) return null

    const option = Array.from(modal
      .querySelectorAll('[data-developer-modal-target="serviceSelect"] option'))
      .find(option => String(option.value) === String(productId)
    )

    if (!option) return null

    return {
      brand: option.dataset.brand || "",
      name: option.dataset.name || option.textContent.trim()
    }
  }

  // DISPLAY
  renderList() {
    if (
      !this.hasListTarget || !this.hasItemTemplateTarget
    ) {
      return
    }

    this.listTarget.innerHTML = ""
    this.oxidants.forEach((oxidant, index) => {
      const row = this.itemTemplateTarget.content.firstElementChild.cloneNode(true)
      const product = this.getProductInfo(oxidant.formula_product_id)
      const brand = oxidant.brand || product?.brand || ""
      const name = oxidant.name || product?.name || oxidant.label ||""
      const displayName = [brand, name].filter(Boolean).join(" ")

      row.querySelector(".dev-name").textContent = displayName || `#${oxidant.formula_product_id}`
      row.querySelector(".dev-ratio").textContent = oxidant.ratio || ""
      row.querySelector(".dev-amount").textContent = `${oxidant.amount || 0}g`
      row.querySelector(".edit-btn").dataset.index = index
      row.querySelector(".delete-btn").dataset.index = index

      this.listTarget.appendChild(row)
    })
  }
}

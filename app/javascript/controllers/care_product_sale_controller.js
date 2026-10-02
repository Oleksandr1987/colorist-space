// app/javascript/controllers/care_product_sale_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["quantity", "price", "total", "submit"]

  static values = {
    stock: Number
  }

  connect() {
    this.normalizeQuantity()
    this.update()
  }

  increment() {
    const quantity = this.quantity

    if (quantity >= this.stockValue) return

    this.quantityTarget.value = quantity + 1
    this.update()
  }

  decrement() {
    const quantity = this.quantity

    if (quantity <= 1) return

    this.quantityTarget.value = quantity - 1
    this.update()
  }

  update() {
    this.normalizeQuantity()

    const total = this.quantity * this.price

    this.totalTarget.textContent = this.formatAmount(total)

    if (this.hasSubmitTarget) {
      this.submitTarget.disabled =
        this.stockValue <= 0 ||
        this.quantity <= 0 ||
        this.quantity > this.stockValue ||
        this.price < 0
    }
  }

  normalizeQuantity() {
    if (!this.hasQuantityTarget) return

    let quantity = this.quantity

    if (quantity < 1) quantity = 1
    if (quantity > this.stockValue) quantity = this.stockValue

    this.quantityTarget.value = quantity
  }

  get quantity() {
    return parseInt(this.quantityTarget.value, 10) || 0
  }

  get price() {
    return parseFloat(this.priceTarget.value) || 0
  }

  formatAmount(value) {
    return new Intl.NumberFormat(document.documentElement.lang || "uk-UA", {
      minimumFractionDigits: 0,
      maximumFractionDigits: 2
    }).format(value)
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "quantity",
    "signedQuantity",
    "newStock",
    "submit",
    "error",
    "increaseButton",
    "decreaseButton"
  ]

  static values = {
    stock: Number
  }

  connect() {
    this.direction = -1
    this.update()
  }

  selectIncrease() {
    this.direction = 1
    this.increaseButtonTarget.classList.add("active")
    this.decreaseButtonTarget.classList.remove("active")
    this.update()
  }

  selectDecrease() {
    this.direction = -1
    this.decreaseButtonTarget.classList.add("active")
    this.increaseButtonTarget.classList.remove("active")
    this.update()
  }

  increment() {
    this.quantityTarget.value = this.quantity + 1
    this.update()
  }

  decrement() {
    if (this.quantity <= 1) return

    this.quantityTarget.value = this.quantity - 1
    this.update()
  }

  update() {
    const newStock = this.stockValue + (this.quantity * this.direction)
    const valid = this.quantity > 0 && newStock >= 0

    this.newStockTarget.textContent = newStock
    this.signedQuantityTarget.value = this.quantity * this.direction

    this.errorTarget.classList.toggle("hidden", valid)
    this.submitTarget.disabled = !valid
  }

  prepareSubmit() {
    this.signedQuantityTarget.value = this.quantity * this.direction
  }

  get quantity() {
    return parseInt(this.quantityTarget.value, 10) || 0
  }
}

// app/javascript/controllers/care_products_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["list", "input", "total"]

  connect() {
    this.products = this.load()
    this.initialProducts = this.cloneProducts(this.products)

    this.render()
  }

  cloneProducts(products) {
    return JSON.parse(JSON.stringify(products || []))
  }

  openModal(event) {
    event.preventDefault()

    window.dispatchEvent(
      new CustomEvent("care-products:open", {
        detail: {
          controller: this,
          products: this.cloneProducts(this.products),
          initialProducts: this.cloneProducts(
            this.initialProducts
          )
        }
      })
    )
  }

  saveFromModal(products) {
    this.products = this.cloneProducts(products)

    this.save()
    this.render()
  }

  load() {
    try {
      let data = JSON.parse(this.inputTarget.value || "[]")

      if (typeof data === "string") {data = JSON.parse(data)}

      return Array.isArray(data) ? data : []
    } catch {
      return []
    }
  }

  save() {
    this.inputTarget.value = JSON.stringify(this.products)

    window.dispatchEvent(new CustomEvent("care-products:changed"))
    window.dispatchEvent(new CustomEvent("wizard:changed"))
  }

  render() {
    this.listTarget.innerHTML = ""

    let total = 0

    this.products.forEach((item, index) => {
      const lineTotal = Number(item.price) * Number(item.qty)

      total += lineTotal

      const availableStock = Number(item.available_stock)
      const maxReached = Number.isFinite(availableStock) && Number(item.qty) >= availableStock

      this.listTarget.insertAdjacentHTML(
        "beforeend",
        `
          <div class="care-product-row">
            <div class="care-product-info">
              <div class="care-product-name">
                ${item.name}
              </div>

              <div class="care-product-price">
                ${item.price} ₴ × ${item.qty}
                = ${lineTotal} ₴
              </div>
            </div>

            <div class="qty-control">
              <button type="button" data-index="${index}" data-action="click->care-products#decreaseQty">
                −
              </button>

              <span class="qty-value">
                ${item.qty}
              </span>

              <button type="button" data-index="${index}" data-action="click->care-products#increaseQty" ${maxReached ? "disabled" : ""}>
                +
              </button>
            </div>

            <button type="button" class="remove-care-product" data-index="${index}" data-action="click->care-products#remove">
              ×
            </button>
          </div>
        `
      )
    })

    this.totalTarget.textContent = `${total} ₴`
  }

  increaseQty(event) {
    const index = parseInt(event.currentTarget.dataset.index, 10)
    const product = this.products[index]

    if (!product) return

    const availableStock = Number(product.available_stock)

    if (
      Number.isFinite(availableStock) && product.qty >= availableStock
    ) {
      alert(`Only ${availableStock} item(s) available`)

      return
    }

    product.qty += 1

    this.refresh()
  }

  decreaseQty(event) {
    const index = parseInt(event.currentTarget.dataset.index, 10)
    const product = this.products[index]

    if (!product || product.qty <= 1) return

    product.qty -= 1

    this.refresh()
  }

  remove(event) {
    const index = parseInt(event.currentTarget.dataset.index, 10)

    if (!this.products[index]) return

    this.products.splice(index, 1)

    this.refresh()
  }

  refresh() {
    this.render()
    this.save()
  }
}

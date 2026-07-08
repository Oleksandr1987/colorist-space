// controllers/care_products_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "list",
    "modal",
    "input",
    "total",
    "search",
    "productsList"
  ]

  async connect() {
    this.products = this.load()
    this.initialProducts = JSON.parse(
      JSON.stringify(this.products)
    )

    await this.reloadCatalog()

    this.render()

    window.dispatchEvent(
      new CustomEvent("care-products:changed")
    )
  }

  async reloadCatalog() {
    const locale =
      document.documentElement.lang || "uk"

    const response = await fetch(
      `/care_products/options?locale=${locale}`
    )

    this.catalog = await response.json()

    this.renderCatalog()
  }

  async openModal() {
    await this.reloadCatalog()

    this.modalTarget.classList.remove("hidden")
  }

  closeModal() {
    this.modalTarget.classList.add("hidden")
  }

  stop(event) {
    event.stopPropagation()
  }

  addProduct(event) {
    const button = event.currentTarget

    const existing = this.products.find(
      p => p.care_product_id == button.dataset.id
    )

    if (existing) {
      const availableStock = this.availableStockFor(existing.care_product_id)

      if (existing.qty >= availableStock) {
        alert(
          `Only ${availableStock} item(s) available`
        )

        return
      }

      existing.qty += 1
    } else {
      const availableStock = this.availableStockFor(button.dataset.id)

      if (availableStock < 1) {
        alert("Product is out of stock")

        return
      }

      this.products.push({
        care_product_id: button.dataset.id,
        name: button.dataset.name,
        price: parseFloat(button.dataset.price),
        qty: 1
      })
    }

    this.refresh()
    this.closeModal()
  }

  load() {
    try {
      let data = JSON.parse(this.inputTarget.value || "[]")

      if (typeof data === "string") {
        data = JSON.parse(data)
      }

      return Array.isArray(data) ? data : []
    } catch {
      return []
    }
  }

  save() {
    this.inputTarget.value = JSON.stringify(this.products)

    console.log(this.inputTarget.value)

    window.dispatchEvent(
      new CustomEvent("care-products:changed")
    )
  }

  filterCategory(event) {
    const category = event.currentTarget.dataset.category

    document
      .querySelectorAll(".filter-button")
      .forEach(button => {
        button.classList.remove("active")
      })

    event.currentTarget.classList.add("active")

    this.productsListTarget
      .querySelectorAll(".care-product-option")
      .forEach(item => {

        if (
          category === "" ||
          item.dataset.category === category
        ) {
          item.classList.remove("hidden")
        } else {
          item.classList.add("hidden")
        }
      })
  }

  stockFor(careProductId) {
    const product = this.catalog.find(
      p => p.id == careProductId
    )

    return product
      ? product.stock_quantity
      : 0
  }

  initialQtyFor(careProductId) {
    const item = this.initialProducts.find(
      p => p.care_product_id == careProductId
    )

    return item
      ? parseInt(item.qty, 10)
      : 0
  }

  availableStockFor(careProductId) {
    return (
      this.stockFor(careProductId) +
      this.initialQtyFor(careProductId)
    )
  }

  render() {
    this.listTarget.innerHTML = ""

    let total = 0

    this.products.forEach((item, index) => {
      const lineTotal = item.price * item.qty
      const availableStock = this.availableStockFor(item.care_product_id)

      total += lineTotal

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

              <button
                type="button"
                data-index="${index}"
                data-action="click->care-products#decreaseQty">

                −

              </button>

              <span class="qty-value">
                ${item.qty}
              </span>

              <button
                type="button"
                data-index="${index}"
                data-action="click->care-products#increaseQty"
                ${
                  item.qty >= availableStock
                    ? "disabled"
                    : ""
                }>

                +

              </button>

            </div>

            <button
              type="button"
              class="remove-care-product"
              data-index="${index}"
              data-action="click->care-products#remove">

              ×

            </button>

          </div>
        `
      )
    }) // ---------------- TODO: Add png

    this.totalTarget.textContent = `${total} ₴`
  }

  renderCatalog() {
    this.productsListTarget.innerHTML = ""

    this.catalog.forEach(product => {
      const remaining =
        this.availableStockFor(product.id) -
        (
          this.products.find(
            p => p.care_product_id == product.id
          )?.qty || 0
        )

      const outOfStock = remaining <= 0

      this.productsListTarget.insertAdjacentHTML(
        "beforeend",
        `
          <div
            class="care-product-option ${
              outOfStock
                ? "out-of-stock"
                : ""
            }"
            data-category="${product.category}">

            <div>

              <strong>
                ${product.brand}
              </strong>

              <div>
                ${product.name}
              </div>

              <small>
                ${product.category}
              </small>

              <br>

              <small>
                ${product.sale_price} ₴
              </small>

              <br>

              <small>
                Stock:
                ${remaining}
              </small>

              ${
                outOfStock
                  ? `
                    <br>

                    <small class="out-of-stock-label">
                      Out of stock
                    </small>
                  `
                  : ""
              }

            </div>

            <button
              type="button"
              data-action="click->care-products#addProduct"
              data-id="${product.id}"
              data-name="${product.name}"
              data-price="${product.sale_price}"
              ${
                outOfStock
                  ? "disabled"
                  : ""
              }>

              ${
                outOfStock
                  ? "×"
                  : "+"
              }

            </button>

          </div>
        `
      )
    })
  }

  increaseQty(event) {
    const index = parseInt(event.currentTarget.dataset.index, 10)
    const product = this.products[index]

    if (!product) return

    const availableStock = this.availableStockFor(product.care_product_id)

    if (product.qty >= availableStock) {
      alert(
        `Only ${availableStock} item(s) available`
      )

      return
    }

    product.qty += 1

    this.refresh()
  }

  decreaseQty(event) {
    const index = parseInt(event.currentTarget.dataset.index)

    if (this.products[index].qty <= 1) {
      return
    }

    this.products[index].qty -= 1
    this.refresh()
  }

  changeQty(event) {
    const index = parseInt(event.currentTarget.dataset.index)
    const qty = parseInt(event.currentTarget.value)

    this.products[index].qty = isNaN(qty) || qty < 1 ? 1 : qty
    this.refresh()
  }

  search() {
    const query = this.searchTarget.value.toLowerCase()

    this.productsListTarget
      .querySelectorAll(".care-product-option")
      .forEach(item => {
        item.classList.toggle(
          "hidden",
          !item.textContent
            .toLowerCase()
            .includes(query)
        )
      })
  }

  refresh() {
    this.render()
    this.renderCatalog()
    this.save()
  }

  remove(event) {
    const index = parseInt(event.currentTarget.dataset.index)

    this.products.splice(index, 1)
    this.refresh()
  }
}

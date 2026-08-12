// app/javascript/controllers/care_products_controller.js
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
    this.initialProducts = this.cloneProducts(this.products)
    this.draftProducts = []

    await this.reloadCatalog()

    this.render()
  }

  cloneProducts(products) {
    return JSON.parse(
      JSON.stringify(products)
    )
  }

  async reloadCatalog() {
    const locale = document.documentElement.lang || "uk"

    const response = await fetch(`/care_products/options?locale=${locale}`)

    this.catalog = await response.json()
    this.renderCatalog()
  }

  async openModal() {
    this.draftProducts = this.cloneProducts(
      this.products
    )

    await this.reloadCatalog()

    this.resetFilters()
    this.modalTarget.classList.remove("hidden")
  }

  cancelModal(event) {
    event?.preventDefault()

    this.draftProducts = []
    this.modalTarget.classList.add("hidden")
  }

  saveModal(event) {
    event.preventDefault()
    event.stopPropagation()

    this.products = this.cloneProducts(
      this.draftProducts
    )

    this.save()
    this.render()

    this.draftProducts = []

    this.modalTarget.classList.add("hidden")
  }

  stop(event) {
    event.stopPropagation()
  }

  addProduct(event) {
    const button = event.currentTarget

    const existing = this.draftProducts.find(
      product =>
        product.care_product_id == button.dataset.id
    )

    if (existing) {
      const availableStock =
        this.availableStockFor(
          existing.care_product_id
        )

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

      this.draftProducts.push({
        care_product_id: button.dataset.id,
        name: button.dataset.name,
        price: parseFloat(button.dataset.price),
        qty: 1
      })
    }

    this.renderCatalog()
  }

  load() {
    try {
      let data = JSON.parse(
        this.inputTarget.value || "[]"
      )

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

    window.dispatchEvent(
      new CustomEvent("care-products:changed")
    )

    window.dispatchEvent(new CustomEvent("wizard:changed"))
  }

  filterCategory(event) {
    const category = event.currentTarget.dataset.category

    this.element
      .querySelectorAll(
        ".care-products-filters .filter-button"
      )
      .forEach(button => {
        button.classList.remove("active")
      })

    event.currentTarget.classList.add("active")

    this.productsListTarget
      .querySelectorAll(".care-product-option")
      .forEach(item => {
        item.classList.toggle(
          "hidden",
          category !== "" &&
            item.dataset.category !== category
        )
      })
  }

  resetFilters() {
    if (this.hasSearchTarget) {
      this.searchTarget.value = ""
    }

    const buttons = this.element.querySelectorAll(".care-products-filters .filter-button")

    buttons.forEach(button => {
      button.classList.remove("active")
    })

    buttons[0]?.classList.add("active")
  }

  stockFor(careProductId) {
    const product = this.catalog.find(
      product => product.id == careProductId
    )

    return product
      ? product.stock_quantity
      : 0
  }

  initialQtyFor(careProductId) {
    const item = this.initialProducts.find(
      product =>
        product.care_product_id == careProductId
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
    })

    this.totalTarget.textContent = `${total} ₴`
  }

  renderCatalog() {
    if (!this.catalog) return

    this.productsListTarget.innerHTML = ""

    const currentProducts =
      this.draftProducts.length > 0 ||
      !this.modalTarget.classList.contains("hidden")
        ? this.draftProducts
        : this.products

    this.catalog.forEach(product => {
      const selected = currentProducts.find(item => item.care_product_id == product.id)
      const qty = selected?.qty || 0
      const remaining = this.availableStockFor(product.id) - qty
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
                Stock: ${remaining}
              </small>

              ${
                qty > 0
                  ? `
                    <br>
                    <small>
                      Selected: ${qty}
                    </small>
                  `
                  : ""
              }

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
    const index = parseInt(event.currentTarget.dataset.index, 10)
    const product = this.products[index]

    if (!product) return

    if (product.qty <= 1) {
      return
    }

    product.qty -= 1

    this.refresh()
  }

  changeQty(event) {
    const index = parseInt(event.currentTarget.dataset.index, 10)
    const qty = parseInt(event.currentTarget.value, 10)

    if (!this.products[index]) return

    this.products[index].qty =
      isNaN(qty) || qty < 1
        ? 1
        : qty

    this.refresh()
  }

  search() {
    const query = this.searchTarget.value.trim().toLowerCase()

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
    this.save()
  }

  remove(event) {
    const index = parseInt(
      event.currentTarget.dataset.index,
      10
    )

    this.products.splice(index, 1)
    this.refresh()
  }
}

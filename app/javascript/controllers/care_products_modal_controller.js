// app/javascript/controllers/care_products_modal_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "search", "productsList"]

  static values = {
    stockLabel: String,
    selectedLabel: String,
    outOfStockLabel: String,
    onlyAvailableMessage: String
  }

  connect() {
    this.sourceController = null

    this.catalog = []
    this.products = []
    this.initialProducts = []

    this.handleOpen = this.handleOpen.bind(this)
    this.handleEsc = this.handleEsc.bind(this)

    window.addEventListener("care-products:open", this.handleOpen)

    document.addEventListener("keydown", this.handleEsc)
  }

  disconnect() {
    window.removeEventListener("care-products:open", this.handleOpen)

    document.removeEventListener("keydown", this.handleEsc)
  }

  cloneProducts(products) {
    return JSON.parse(JSON.stringify(products || []))
  }

  // OPEN
  async handleOpen(event) {
      const {controller, products, initialProducts} = event.detail

      this.sourceController = controller
      this.products = this.cloneProducts(products)
      this.initialProducts =
        this.cloneProducts(initialProducts)

      await this.reloadCatalog()

      this.products.forEach(product => {
        product.available_stock = this.availableStockFor(product.care_product_id)
      })

      this.resetFilters()
      this.renderCatalog()

      this.modalTarget.classList.remove("hidden")
    }

  // CLOSE
  cancelModal(event) {
    event?.preventDefault()

    this.modalTarget.classList.add("hidden")

    this.products = []
    this.sourceController = null
  }

  stop(event) {
    event.stopPropagation()
  }

  handleEsc(event) {
    if (
      event.key === "Escape" && !this.modalTarget.classList.contains("hidden")
    ) {
      this.cancelModal()
    }
  }

  // SAVE
  saveModal(event) {
    event.preventDefault()
    event.stopPropagation()

    if (!this.sourceController) return

    this.sourceController.saveFromModal(this.cloneProducts(this.products))
    this.modalTarget.classList.add("hidden")
    this.products = []
    this.sourceController = null
  }

  // CATALOG
  async reloadCatalog() {
    const locale = document.documentElement.lang || "uk"
    const response = await fetch(`/care_products/options?locale=${encodeURIComponent(locale)}`)

    if (!response.ok) {
      this.catalog = []
      return
    }

    this.catalog = await response.json()
  }

  stockFor(careProductId) {
    const product = this.catalog.find(product => product.id == careProductId)

    return product ? Number(product.stock_quantity) || 0 : 0
  }

  initialQtyFor(careProductId) {
    const item = this.initialProducts.find(product => product.care_product_id == careProductId)

    return item ? parseInt(item.qty, 10) || 0 : 0
  }

  availableStockFor(careProductId) {
    return (this.stockFor(careProductId) + this.initialQtyFor(careProductId))
  }

  // ADD
  addProduct(event) {
    event.preventDefault()

    const button = event.currentTarget
    const existing = this.products.find(product => product.care_product_id == button.dataset.id)
    const availableStock = this.availableStockFor(button.dataset.id)

    if (existing) {
      existing.available_stock = availableStock

      if (existing.qty >= availableStock) {
        alert(this.onlyAvailableMessageValue.replace("%{count}", availableStock))
        return
      }

      existing.qty += 1
    } else {
      if (availableStock < 1) {
        alert(this.outOfStockLabelValue)
        return
      }

      this.products.push({
        care_product_id: button.dataset.id,
        name: button.dataset.name,
        price: parseFloat(button.dataset.price),
        qty: 1,
        available_stock: availableStock
      })
    }

    this.renderCatalog()
  }

  // RENDER
  renderCatalog() {
    if (!this.hasProductsListTarget) return

    this.productsListTarget.innerHTML = ""

    this.catalog.forEach(product => {
      const selected = this.products.find(item => item.care_product_id == product.id)

      const qty = selected?.qty || 0
      const remaining = this.availableStockFor(product.id) - qty
      const outOfStock = remaining <= 0

      this.productsListTarget.insertAdjacentHTML(
        "beforeend",
        `
          <div class="care-product-option ${outOfStock ? "out-of-stock" : ""}" data-category="${product.category}">
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
                ${this.stockLabelValue}: ${remaining}
              </small>

              ${qty > 0 ? `<br><small>${this.selectedLabelValue}: ${qty}</small>` : ""}

              ${outOfStock ? `<br><small class="out-of-stock-label">${this.outOfStockLabelValue}</small>` : ""}
            </div>

            <button type="button" data-action="click->care-products-modal#addProduct"
              data-id="${product.id}"
              data-name="${product.name}"
              data-price="${product.sale_price}"
              ${outOfStock ? "disabled" : ""}>
              ${outOfStock ? "×" : "+"}
            </button>
          </div>
        `
      )
    })

    this.applyFilters()
  }

  // FILTER
  filterCategory(event) {
    this.selectedCategory = event.currentTarget.dataset.category || ""

    this.element
      .querySelectorAll(".care-products-filters .filter-button")
      .forEach(button => {
        button.classList.remove("active")
      })

    event.currentTarget.classList.add("active")

    this.applyFilters()
  }

  resetFilters() {
    this.selectedCategory = ""

    if (this.hasSearchTarget) {
      this.searchTarget.value = ""
    }

    const buttons = this.element.querySelectorAll(".care-products-filters .filter-button")

    buttons.forEach(button => {
      button.classList.remove("active")
    })

    buttons[0]?.classList.add("active")

    this.applyFilters()
  }

  search() {
    this.applyFilters()
  }

  applyFilters() {
    if (!this.hasProductsListTarget) return

    const query = this.hasSearchTarget ? this.searchTarget.value.trim().toLowerCase() : ""

    const category = this.selectedCategory || ""

    this.productsListTarget
      .querySelectorAll(".care-product-option")
      .forEach(item => {
        const matchesCategory = category === "" || item.dataset.category === category

        const matchesSearch = query === "" || item.textContent.toLowerCase().includes(query)

        item.classList.toggle("hidden", !(matchesCategory && matchesSearch))
      })
  }
}

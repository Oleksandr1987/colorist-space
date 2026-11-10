// app/javascript/controllers/service_note_controller.js.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "priceValue",
    "priceInput",
    "servicesList",
    "servicesSection",
    "formulaSection",
    "colorsGroup",
    "colorsList",
    "colorsTotal",
    "additivesGroup",
    "additivesList",
    "additivesTotal",
    "developerGroup",
    "developerList",
    "developerTotal",
    "developerPrice",
    "careSection",
    "careProductsList",
    "careTotal",
    "finalPrice"
  ]

  static values = {
    formulaPriceLabel: String,
    careProductsPriceLabel: String
  }

  connect() {
    this.services = []
    this.handleServicesChanged = event => { this.updateServices(event.detail?.services || []) }
    this.handleRefresh = () => this.refreshReceipt()
    this.handleCareProductsChanged = () => this.refreshReceipt()
    this.handleFormulaChanged = () => this.refreshReceipt()

    window.addEventListener("service-selector:changed", this.handleServicesChanged)
    window.addEventListener("formula:changed", this.handleFormulaChanged)
    window.addEventListener("formula:colorAmountChanged", this.handleFormulaChanged)
    window.addEventListener("care-products:changed", this.handleCareProductsChanged)
    window.addEventListener("service-note:refresh", this.handleRefresh)

    this.loadInitialServices()
    this.refreshReceipt()
  }

  disconnect() {
    window.removeEventListener("service-selector:changed", this.handleServicesChanged)
    window.removeEventListener("formula:changed", this.handleFormulaChanged)
    window.removeEventListener("formula:colorAmountChanged", this.handleFormulaChanged)
    window.removeEventListener("care-products:changed", this.handleCareProductsChanged)
    window.removeEventListener("service-note:refresh", this.handleRefresh)
  }

  number(value) {
    const result = Number(String(value ?? "0").replace(",", "."))
    return Number.isFinite(result) ? result : 0
  }

  money(value) {
    return `${new Intl.NumberFormat("uk-UA", {
      minimumFractionDigits: 0, maximumFractionDigits: 2
    }).format(value)} ₴`
  }

  quantity(value, unit = "") {
    const amount = new Intl.NumberFormat("uk-UA", {
      maximumFractionDigits: 2
    }).format(value)

    return unit ? `${amount} ${unit}` : amount
  }

  setText(target, value) {
    if (target) target.textContent = value
  }

  setVisible(target, visible) {
    if (target) target.hidden = !visible
  }

  createRow(columns, className) {
    const row = document.createElement("div")
    row.className = `receipt-row ${className}`

    columns.forEach(value => {
      const cell = document.createElement("span")
      cell.textContent = String(value ?? "")
      row.appendChild(cell)
    })

    return row
  }

  renderRows(target, items, columns) {
    if (!target) return

    target.replaceChildren()

    items.forEach(item => {
      const values = columns(item)

      target.appendChild(this.createRow(values, `receipt-cols-${values.length}`))
    })
  }

  loadInitialServices() {
    const selectorElement = this.element.closest('[data-controller~="service-selector"]')
    if (!selectorElement) return

    const controller = this.application.getControllerForElementAndIdentifier(selectorElement, "service-selector")
    if (!controller) return

    this.services = controller.selected || []
  }

  updateServices(services) {
    this.services = services
    this.refreshReceipt()
  }

  calculateServices() {
    return this.services.reduce((sum, service) => sum + this.number(service.price), 0)
  }

  renderServices() {
    const total = this.calculateServices()

    this.renderRows( this.servicesListTarget, this.services,
      service => [ service.subtype || service.name || "", this.money(this.number(service.price)) ]
    )

    this.setText(this.priceValueTarget, this.money(total))
    this.setVisible(this.servicesSectionTarget, this.services.length > 0)

    if (this.hasPriceInputTarget) {
      this.priceInputTarget.value = total
    }

    return total
  }

  activeFormulaSteps() {
    return [...document.querySelectorAll(".formula-step-wrapper")]
      .filter(step => {
        if (step.closest("template")) return false
        return step.querySelector(".destroy-field")?.value !== "1"
      })
  }

  ingredientItems(kind) {
    const items = new Map()

    this.activeFormulaSteps().forEach(step => {
      step.querySelectorAll(".ingredient-fields").forEach(wrapper => {
        if (wrapper.closest("template")) return
        if (wrapper.querySelector("[data-field='destroy']")?.value === "1") return

        const field = name => wrapper.querySelector(`[data-field="${name}"]`)?.value || ""

        if ((field("kind") || "color") !== kind) return

        const amount = this.number(field("amount"))
        if (amount <= 0) return

        const price = this.number(field("price"))
        const brand = field("brand")
        const shade = field("shade")
        const productId = field("formula_product_id")

        const option = [...document.querySelectorAll(
          '[data-color-target="paletteTemplate"] option, ' +
          '[data-additive-target="productTemplate"] option'
        )].find(option => option.value === productId)

        const unit = wrapper.dataset.unit || option?.dataset.unit || "g"
        const name = [brand, shade].filter(Boolean).join(" ").trim()

        const key = JSON.stringify([productId || null, brand, shade, unit, price])

        if (!items.has(key)) {
          items.set(key, { name, unit, amount: 0, total: 0 })
        }

        const item = items.get(key)
        item.amount += amount
        item.total += amount * price
      })
    })

    return [...items.values()]
  }

  oxidantItems() {
    const items = new Map()

    this.activeFormulaSteps().forEach(step => {
      step.querySelectorAll("input[name*='[oxidant]']").forEach(input => {
        if (!input.value) return

        let oxidants

        try {
          oxidants = JSON.parse(input.value)
        } catch {
          return
        }

        if (!Array.isArray(oxidants)) oxidants = [oxidants]

        oxidants.forEach(data => {
          if (!data || typeof data !== "object") return

          const productId = data.formula_product_id || data.service_id
          const amount = this.number(data.amount)
          const price = this.number(data.price)

          if (amount <= 0) return

          const option = [...document.querySelectorAll("option")]
            .find(option => String(option.value) === String(productId) && (option.dataset.brand || option.dataset.name))

          const brand = data.brand || option?.dataset.brand || ""
          const name = data.name || option?.dataset.name || ""
          const unit = data.unit || option?.dataset.unit || "g"

          const key = JSON.stringify([productId, brand, name, unit, price])

          if (!items.has(key)) {
            items.set(key, {
              name: [brand, name].filter(Boolean).join(" "), unit, amount: 0, total: 0
            })
          }

          const item = items.get(key)
          item.amount += amount
          item.total += amount * price
        })
      })
    })

    return [...items.values()]
  }

  renderIngredientGroup(items, list, totalTarget, groupTarget) {
    const total = items.reduce((sum, item) => sum + item.total, 0)

    this.renderRows(list, items, item => [ item.name, this.quantity(item.amount, item.unit), this.money(item.total) ])
    this.setText(totalTarget, this.money(total))
    this.setVisible(groupTarget, items.length > 0)

    return total
  }

  renderFormula() {
    const colors = this.ingredientItems("color")
    const additives = this.ingredientItems("additive")
    const oxidants = this.oxidantItems()
    const colorsTotal = this.renderIngredientGroup(colors, this.colorsListTarget, this.colorsTotalTarget, this.colorsGroupTarget)
    const additivesTotal = this.renderIngredientGroup(additives, this.additivesListTarget, this.additivesTotalTarget, this.additivesGroupTarget)
    const oxidantsTotal = this.renderIngredientGroup(oxidants, this.developerListTarget, this.developerTotalTarget, this.developerGroupTarget)
    const total = colorsTotal + additivesTotal + oxidantsTotal

    this.setText(this.developerPriceTarget, this.money(total))
    this.setVisible(this.formulaSectionTarget, colors.length + additives.length + oxidants.length > 0)

    return total
  }

  careProductItems() {
    const input = document.querySelector( "input[name='service_note[care_products]']")

    if (!input) return []

    try {
      let products = JSON.parse(input.value || "[]")

      if (typeof products === "string") {
        products = JSON.parse(products)
      }

      if (!Array.isArray(products)) return []

      return products
        .map(product => {
          const qty = this.number(product.qty)
          const price = this.number(product.price)

          const brand = product.brand || ""
          const category = product.category || ""
          const name = product.name || ""

          return { name: [brand, name].filter(Boolean).join(" "), category, qty, total: qty * price }
        })
        .filter(item => item.qty > 0)
    } catch {
      return []
    }
  }

  renderCareProducts() {
    const products = this.careProductItems()
    const total = products.reduce((sum, product) => sum + product.total, 0)

    if (this.hasCareProductsListTarget) {
      this.careProductsListTarget.replaceChildren()

      products.forEach(product => {
        const row = this.createRow([product.name, this.quantity(product.qty, "шт."), this.money(product.total)], "receipt-cols-3")

        if (product.category) {
          const category = document.createElement("small")
          category.className = "receipt-product-category"
          category.textContent = product.category
          row.firstElementChild.appendChild(category)
        }

        this.careProductsListTarget.appendChild(row)
      })
    }

    this.setText(this.careTotalTarget, this.money(total))
    this.setVisible(this.careSectionTarget, products.length > 0)

    return total
  }

  refreshReceipt() {
    this.loadInitialServices()

    const services = this.renderServices()
    const formula = this.renderFormula()
    const care = this.renderCareProducts()

    this.setText(this.finalPriceTarget, this.money(services + formula + care))
  }

  calculateFinal() {
    this.refreshReceipt()
  }
}

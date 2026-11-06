// app/javascript/controllers/service_note_controller.js.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "tab",
    "tabContent",
    "priceValue",
    "priceInput",
    "servicesList",
    "colorsList",
    "developerPrice",
    "developerAmount",
    "developerList",
    "additivesList",
    "finalPrice",
    "careProductsList"
  ]

  static values = {
    formulaPriceLabel: String,
    careProductsPriceLabel: String
  }

  connect() {
    this.services = []

    this.handleServicesChanged = (event) => {
      this.updateServices(event.detail?.services || [])
    }

    window.addEventListener("services:changed", this.handleServicesChanged)

    this.loadInitialServices()

    this.handleFormulaChanged = () => {
      this.calculateFinal()
    }

    this.handleCareProductsChanged = () => {
      this.renderCareProducts()
      this.calculateFinal()
    }

    window.addEventListener("formula:changed", this.handleFormulaChanged)
    window.addEventListener("formula:colorAmountChanged", this.handleFormulaChanged)
    window.addEventListener("care-products:changed", this.handleCareProductsChanged)

    this.renderCareProducts()
    this.calculateFinal()
  }

  disconnect() {
    window.removeEventListener("services:changed", this.handleServicesChanged)
    window.removeEventListener("formula:colorAmountChanged", this.handleFormulaChanged)
    window.removeEventListener("formula:changed", this.handleFormulaChanged)
    window.removeEventListener("care-products:changed", this.handleCareProductsChanged)
  }

  updateServices(services) {
    this.services = services

    this.recalculatePrice()
    this.renderServices()
    this.calculateFinal()
  }

  loadInitialServices() {
    const selectorElement = this.element.closest('[data-controller~="service-selector"]')

    if (!selectorElement) return

    const selectorController = this.application.getControllerForElementAndIdentifier(selectorElement, "service-selector")

    if (!selectorController) return

    this.updateServices(selectorController.selected || [])
  }

  showTab(event) {
    const name = event.currentTarget.dataset.tabName

    this.tabTargets.forEach(tab => tab.classList.remove("active"))
    event.currentTarget.classList.add("active")

    this.tabContentTargets.forEach(content => {
      content.classList.toggle("active", content.id === `${name}-tab`)
      content.classList.toggle("hidden", content.id !== `${name}-tab`)
    })
  }

  recalculatePrice() {
    const total = this.services.reduce((sum, service) => sum + Number(service.price || 0), 0)

    if (this.hasPriceValueTarget) {
      this.priceValueTarget.innerHTML = `<strong>${total} ₴</strong>`
    }

    if (this.hasPriceInputTarget) {
      this.priceInputTarget.value = total
    }
  }

  renderServices() {
    if (!this.hasServicesListTarget) return

    this.servicesListTarget.innerHTML = ""

    this.services.forEach(service => {
      this.servicesListTarget.insertAdjacentHTML(
        "beforeend",
        `
          <div class="notes-service-item" data-id="${service.id}">
            <span>${service.subtype}</span>
          </div>
        `
      )
    })
  }

  removeFromNotes(event) {
    const id = event.currentTarget.closest(".notes-service-item").dataset.id

    window.dispatchEvent(
      new CustomEvent("service-selector:remove", {detail: { id }})
    )
  }

  calculateServices() {
    return this.services.reduce((sum, service) => sum + Number(service.price || 0), 0)
  }

  calculateDeveloper() {
    let total = 0
    const grouped = {}

    document.querySelectorAll("input[name*='[oxidant]']").forEach(input => {
      if (!input.value) return

      let items

      try {
        items = JSON.parse(input.value)
      } catch {
        console.warn("Invalid oxidant JSON:", input.value)
        return
      }

      if (!Array.isArray(items)) {
        items = [items]
      }

      items.forEach(data => {
        const serviceId = data.formula_product_id || data.service_id
        const amount = parseFloat(data.amount || 0)
        const price = parseFloat(data.price || 0)
        if (!serviceId || isNaN(amount) || isNaN(price)) return

        const serviceOption = document.querySelector(`option[value="${serviceId}"]`)
        const brand = data.brand || serviceOption?.dataset.brand || ""
        const name = data.name || serviceOption?.dataset.name || serviceOption?.textContent.trim() || "Developer"
        const unit = data.unit || serviceOption?.dataset.unit || "g"

        if (!grouped[serviceId]) {
          grouped[serviceId] = { name, brand, unit, amount: 0, total: 0 }
        }

        grouped[serviceId].amount += amount
        grouped[serviceId].total += amount * price

        total += amount * price
      })
    })


    this.renderDeveloperList(grouped)

    return total
  }

  renderDeveloperList(grouped) {
    if (!this.hasDeveloperListTarget) return

    this.developerListTarget.replaceChildren()
    if (this.hasColorsListTarget) this.colorsListTarget.replaceChildren()
    if (this.hasAdditivesListTarget) this.additivesListTarget.replaceChildren()

    const colors = new Map()
    const additives = new Map()

    document.querySelectorAll(".ingredient-fields").forEach(wrapper => {
      if (wrapper.closest("template")) return
      if (wrapper.closest(".formula-step-wrapper")?.querySelector(".destroy-field")?.value === "1") return
      if (wrapper.querySelector("[data-field='destroy']")?.value === "1") return

      const value = field => wrapper.querySelector(`[data-field="${field}"]`)?.value || ""

      const kind = value("kind") || "color"
      if (!["color", "additive"].includes(kind)) return

      const brand = value("brand")
      const shade = value("shade")
      const amount = Number(value("amount").replace(",", "."))

      if (!shade || !Number.isFinite(amount) || amount <= 0) return

      const productId = value("formula_product_id")
      const option = [...document.querySelectorAll(
        '[data-color-target="paletteTemplate"] option, ' +
        '[data-additive-target="productTemplate"] option'
      )].find(item => item.value === productId)

      const unit = option?.dataset.unit || "g"
      const collection = kind === "additive" ? additives : colors
      const key = `${brand}|${shade}|${unit}`

      if (!collection.has(key)) {
        collection.set(key, { brand, shade, unit, amount: 0 })
      }

      collection.get(key).amount += amount
    })

    const renderRows = (collection, target) => {
      if (!target) return

      collection.forEach(item => {
        const row = document.createElement("div")
        row.className = "notes-dev-row"

        const name = document.createElement("span")
        name.textContent = `${item.brand} ${item.shade}`.trim()

        const amount = document.createElement("span")
        amount.textContent = `${item.amount}${item.unit}`

        row.append(name, amount)
        target.appendChild(row)
      })
    }

    renderRows(colors, this.hasColorsListTarget ? this.colorsListTarget : null)
    renderRows(additives, this.hasAdditivesListTarget ? this.additivesListTarget : null)

    let oxidantsTotal = 0

    Object.values(grouped).forEach(dev => {
      oxidantsTotal += dev.total

      const row = document.createElement("div")
      row.className = "notes-dev-row"

      const name = document.createElement("span")
      name.textContent = `${dev.brand} ${dev.name}`.trim()

      const amount = document.createElement("span")
      amount.textContent = `${dev.amount}${dev.unit}`

      row.append(name, amount)
      this.developerListTarget.appendChild(row)
    })

    if (this.hasDeveloperPriceTarget) {
      const formulaTotal =
        this.calculateColorsPrice() +
        this.calculateAdditivesPrice() +
        oxidantsTotal

      this.developerPriceTarget.replaceChildren()

      const label = document.createElement("span")
      const strong = document.createElement("strong")
      strong.textContent = this.formulaPriceLabelValue
      label.appendChild(strong)

      const price = document.createElement("span")
      price.textContent = `${formulaTotal} ₴`

      this.developerPriceTarget.append(label, price)
    }
  }

  renderCareProducts() {
    if (!this.hasCareProductsListTarget) return

    const input = document.querySelector("input[name='service_note[care_products]']")

    if (!input) return

    let products = []

    try {
      products = JSON.parse(input.value || "[]")

      if (typeof products === "string") {
        products = JSON.parse(products)
      }

      if (!Array.isArray(products)) {
        products = []
      }
    } catch {
      products = []
    }

    let total = 0

    this.careProductsListTarget.innerHTML = ""

    products.forEach(product => {
      const qty = parseFloat(product.qty || 0)
      const price = parseFloat(product.price || 0)

      total += qty * price

      this.careProductsListTarget.insertAdjacentHTML(
        "beforeend",
        `
          <div class="notes-care-row">
            <span>${product.name}</span>
            <span> ${qty}</span>
          </div>
        `
      )
    })

    this.careProductsListTarget.insertAdjacentHTML(
      "beforeend",
      `
        <div class="notes-care-total">
          <span><strong>${this.careProductsPriceLabelValue}</strong></span>
          <span>${total} ₴</span>
        </div>
      `
    )
  }

  calculateColorsPrice() {
    return this.calculateIngredientsPrice("color")
  }

  calculateAdditivesPrice() {
    return this.calculateIngredientsPrice("additive")
  }

  calculateIngredientsPrice(kind) {
    let total = 0

    document.querySelectorAll(".ingredient-fields").forEach(wrapper => {
      if (wrapper.closest("template")) return
      if (wrapper.closest(".formula-step-wrapper")?.querySelector(".destroy-field")?.value === "1") return

      const destroy = wrapper.querySelector("[data-field='destroy']")
      if (destroy?.value === "1") return

      const ingredientKind = wrapper.querySelector("[data-field='kind']")?.value || "color"

      if (ingredientKind !== kind) return

      const amount = Number((wrapper.querySelector("[data-field='amount']")?.value || "0").replace(",", "."))
      const price = Number((wrapper.querySelector("[data-field='price']")?.value || "0").replace(",", "."))

      if (Number.isFinite(amount) && Number.isFinite(price)) {
        total += amount * price
      }
    })

    return total
  }

  calculateCareProducts() {
    const input = document.querySelector("input[name='service_note[care_products]']")

    if (!input) return 0

    let products = []

    try {
      products = JSON.parse(input.value || "[]")

      if (typeof products === "string") {
        products = JSON.parse(products)
      }

      if (!Array.isArray(products)) {
        products = []
      }
    } catch {
      return 0
    }

    return products.reduce((sum, item) => {
      return sum + (parseFloat(item.price || 0) * parseFloat(item.qty || 0))
    }, 0)
  }

  calculateFinal() {
    const services = this.calculateServices()
    const oxidants = this.calculateDeveloper()
    const colors = this.calculateColorsPrice()
    const care = this.calculateCareProducts()
    const additives = this.calculateAdditivesPrice()

    let developerGrams = 0

    document.querySelectorAll("input[name*='[oxidant]']").forEach(input => {
      if (!input.value) return

      try {
        const items = JSON.parse(input.value)

        ;(Array.isArray(items) ? items : [items]).forEach(data => {
          const amount = parseFloat(data.amount || 0)

          if (!isNaN(amount)) {
            developerGrams += amount
          }
        })
      } catch {}
    })

    const final = services + oxidants + colors + additives + care

    if (this.hasFinalPriceTarget) {
      this.finalPriceTarget.innerHTML = `<strong>${final} ₴</strong>`
    }
  }
}

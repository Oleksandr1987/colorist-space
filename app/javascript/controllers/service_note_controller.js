// app/javascript/controllers/service_note_controller.js.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "tabContent", "priceValue", "priceInput", "servicesList", "developerPrice", "developerAmount", "developerList", "finalPrice", "careProductsList"]

  connect() {
    this.handleServicesChanged = () => {
      this.recalculatePrice()
      this.renderServices()
      this.calculateFinal()
    }

    window.addEventListener("services:changed", this.handleServicesChanged)

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

    this.handleServicesChanged()
    this.renderCareProducts()
  }

  disconnect() {
    window.removeEventListener("services:changed", this.handleServicesChanged)
    window.removeEventListener("formula:colorAmountChanged", this.handleFormulaChanged)
    window.removeEventListener("formula:changed", this.handleFormulaChanged)
    window.removeEventListener("care-products:changed", this.handleCareProductsChanged)
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
    const form = this.element.closest("form")

    if (!form) return

    const inputs = form.querySelectorAll(
      "input[name='service_note[service_ids][]']:checked"
    )

    let total = 0

    inputs.forEach(el => {
      const price = parseInt(el.dataset.price || 0)
      total += price
    })

    if (this.hasPriceValueTarget) {
      this.priceValueTarget.textContent = total
    }

    if (this.hasPriceInputTarget) {
      this.priceInputTarget.value = total
    }
  }

  renderServices() {
    if (!this.hasServicesListTarget) return

    const form = this.element.closest("form")

    const checked = form.querySelectorAll(
      "input[name='service_note[service_ids][]']:checked"
    )

    this.servicesListTarget.innerHTML = ""

    checked.forEach(el => {
      const name = el.dataset.name
      const id = el.value

      const html = `
        <div class="notes-service-item" data-id="${id}">
          <span>${name}</span>
        </div>
      `

      this.servicesListTarget.insertAdjacentHTML("beforeend", html)
    })
  }

  removeFromNotes(event) {
    const row = event.currentTarget.closest(".notes-service-item")
    const id = row.dataset.id

    const checkbox = document.querySelector(
      `input[name='service_note[service_ids][]'][value='${id}']`
    )

    if (checkbox) checkbox.checked = false

    window.dispatchEvent(new CustomEvent("services:changed"))
  }

  calculateServices() {
    let total = 0

    const form = this.element.closest("form")
    if (!form) return 0

    const inputs = form.querySelectorAll(
      "input[name='service_note[service_ids][]']:checked"
    )

    inputs.forEach(el => {
      total += parseFloat(el.dataset.price || 0)
    })

    return total
  }

  calculateDeveloper() {
    let total = 0
    const grouped = {}

    document.querySelectorAll("input[name*='[oxidant]']").forEach(input => {
      if (!input.value) return

      let data

      try {
        data = JSON.parse(input.value)
      } catch {
        console.warn("Invalid oxidant JSON:", input.value)
        return
      }

      const serviceId = data.formula_product_id || data.service_id
      const amount = parseFloat(data.amount || 0)
      const price = parseFloat(data.price || 0)

      if (!serviceId || isNaN(amount) || isNaN(price)) return

      const serviceOption = document.querySelector(
        `option[value='${serviceId}']`
      )

      const name = serviceOption
        ? serviceOption.textContent.split("(")[0].trim()
        : "Developer"

      if (!grouped[serviceId]) {
        grouped[serviceId] = {
          name,
          amount: 0,
          total: 0
        }
      }

      grouped[serviceId].amount += amount
      grouped[serviceId].total += amount * price

      total += amount * price
    })

    this.renderDeveloperList(grouped)

    return total
  }

  renderDeveloperList(grouped) {
    if (!this.hasDeveloperListTarget) return

    this.developerListTarget.innerHTML = ""

    let total = 0

    //
    // COLORS
    //
    const colors = {}

    document.querySelectorAll(
      ".ingredient-fields"
    ).forEach(wrapper => {

      const destroy =
        wrapper.querySelector(
          "[data-field='destroy']"
        )

      if (destroy?.value === "1") return

      const shade =
        wrapper.querySelector(
          "[data-field='shade']"
        )?.value

      const amount =
        parseFloat(
          wrapper.querySelector(
            "[data-field='amount']"
          )?.value || 0
        )

      if (!shade || amount <= 0) return

      if (!colors[shade]) {
        colors[shade] = 0
      }

      colors[shade] += amount
    })

    if (Object.keys(colors).length > 0) {

      this.developerListTarget.insertAdjacentHTML(
        "beforeend",
        `
          <div class="notes-subtitle">
            Colors
          </div>
        `
      )

      Object.entries(colors).forEach(([name, amount]) => {

        this.developerListTarget.insertAdjacentHTML(
          "beforeend",
          `
            <div class="notes-dev-row">
              <span>${name}</span>
              <span>${amount}g</span>
            </div>
          `
        )
      })
    }

    //
    // OXIDANTS
    //
    if (Object.keys(grouped).length > 0) {

      this.developerListTarget.insertAdjacentHTML(
        "beforeend",
        `
          <div class="notes-subtitle">
            Oxidants
          </div>
        `
      )

      Object.values(grouped).forEach(dev => {

        total += dev.total

        this.developerListTarget.insertAdjacentHTML(
          "beforeend",
          `
            <div class="notes-dev-row">
              <span>${dev.name}</span>
              <span>${dev.amount}g</span>
            </div>
          `
        )
      })
    }

    const colorsPrice = this.calculateColorsPrice()

    total += colorsPrice

    if (this.hasDeveloperPriceTarget) {
      this.developerPriceTarget.innerHTML =
        `Formula Ingredients price: ${total} ₴`
    }
  }

  renderCareProducts() {
    if (!this.hasCareProductsListTarget) return

    const input = document.querySelector(
      "input[name='service_note[care_products]']"
    )

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
          Care products price: ${total} ₴
        </div>
      `
    )
  }

  calculateColorsPrice() {
    let total = 0

    document.querySelectorAll(".ingredient-fields")
      .forEach(wrapper => {

        const destroy =
          wrapper.querySelector(
            "[data-field='destroy']"
          )

        if (destroy?.value === "1") return

        const amount =
          parseFloat(
            wrapper.querySelector(
              "[data-field='amount']"
            )?.value || 0
          )

        const price =
          parseFloat(
            wrapper.querySelector(
              "[data-field='price']"
            )?.value || 0
          )

        total += amount * price
      })

    return total
  }

  calculateCareProducts() {
    const input = document.querySelector(
      "input[name='service_note[care_products]']"
    )

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
      return sum + (
        parseFloat(item.price || 0) *
        parseFloat(item.qty || 0)
      )
    }, 0)
  }

  calculateFinal() {
    const services = this.calculateServices()
    const oxidants = this.calculateDeveloper()
    const colors = this.calculateColorsPrice()
    const care = this.calculateCareProducts()

    let developerGrams = 0

    document.querySelectorAll("input[name*='[oxidant]']").forEach(input => {
      if (!input.value) return

      try {
        const data = JSON.parse(input.value)
        const amount = parseFloat(data.amount || 0)

        if (!isNaN(amount)) {
          developerGrams += amount
        }
      } catch {}
    })

    const final = services + oxidants + colors + care

    if (this.hasPriceValueTarget) {
      this.priceValueTarget.textContent = services
    }

    if (this.hasFinalPriceTarget) {
      this.finalPriceTarget.textContent = final
    }
  }
}

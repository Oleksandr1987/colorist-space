// app/javascript/controllers/service_note_controller.js.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "tabContent", "priceValue", "priceInput", "servicesList", "developerPrice", "developerAmount", "developerList", "finalPrice"]

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

    window.addEventListener("formula:changed", this.handleFormulaChanged)

    window.addEventListener("formula:colorAmountChanged", this.handleFormulaChanged)

    this.handleServicesChanged()
  }

  disconnect() {
    window.removeEventListener("services:changed", this.handleServicesChanged)
    window.removeEventListener("formula:colorAmountChanged", this.handleFormulaChanged)
    window.removeEventListener("formula:changed", this.handleFormulaChanged)
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
          <button type="button"
                  class="remove"
                  data-action="click->service-note#removeFromNotes">
            ×
          </button>
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

      const serviceId = data.service_id
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

    Object.values(grouped).forEach(dev => {
      const html = `
        <div class="notes-dev-row">
          <span class="notes-dev-name">
            ${dev.name}
          </span>

          <span class="notes-dev-info">
            ${dev.amount}g ${dev.total} ₴
          </span>
        </div>
      `

      this.developerListTarget.insertAdjacentHTML("beforeend", html)
    })
  }

  calculateCareProducts() {
    let total = 0

    this.element.querySelectorAll("[data-care-products-item]").forEach(item => {
      const price = parseFloat(item.dataset.price || 0)
      const qty = parseInt(item.dataset.qty || 0)

      total += price * qty
    })

    return total
  }

  calculateFinal() {
    const services = this.calculateServices()
    const developer = this.calculateDeveloper()
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

    const final = services + developer + care

    if (this.hasPriceValueTarget) {
      this.priceValueTarget.textContent = services
    }

    if (this.hasFinalPriceTarget) {
      this.finalPriceTarget.textContent = final
    }

    if (this.hasDeveloperPriceTarget) {
      this.developerPriceTarget.textContent = developer + " ₴"
    }

    if (this.hasDeveloperAmountTarget) {
      this.developerAmountTarget.textContent = developerGrams + "g"
    }
  }
}

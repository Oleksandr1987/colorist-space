import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "tabContent", "priceValue", "priceInput", "servicesList"]

  connect() {
    this.handleServicesChanged = () => {
      this.recalculatePrice()
      this.renderServices()
    }

    window.addEventListener("services:changed", this.handleServicesChanged)

    this.handleServicesChanged()
  }

  disconnect() {
    window.removeEventListener("services:changed", this.handleServicesChanged)
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
}

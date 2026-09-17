// app/javascript/controllers/service_selector_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "list",
    "selected",
    "hiddenInput",
    "selectedContent",
    "placeholder"
  ]

  static values = {
    inputName: String,
    checkboxName: String,
    placeholderClass: String,
    closeIcon: String,
    prices: Object
  }

  connect() {
    this.selected = []

    if (this.hasHiddenInputTarget && this.hiddenInputTarget.value) {
      const existingIds = this.hiddenInputTarget.value
        .split(",")
        .map(id => parseInt(id))
        .filter(Boolean)

      document
        .querySelectorAll(
          `input[type="checkbox"][name="${this.checkboxNameValue}"]`
        )
        .forEach((checkbox) => {
          const id = parseInt(checkbox.value)

          if (existingIds.includes(id)) {
            checkbox.checked = true

            const snapshotPrice = this.hasPricesValue ? this.pricesValue[String(id)] : undefined

            this.selected.push({
              id: checkbox.value,
              name: checkbox.dataset.name,
              subtype: checkbox.dataset.subtype,
              price: snapshotPrice ?? checkbox.dataset.price,
              serviceType: checkbox.dataset.serviceType
            })
          }
        })
    }

    this.boundRemove = this.removeById.bind(this)

    window.addEventListener(
      "service-selector:remove",
      this.boundRemove
    )

    this.updateSelected()
  }

  disconnect() {
    window.removeEventListener(
      "service-selector:remove",
      this.boundRemove
    )
  }

  open(event) {
    const type = event.currentTarget.dataset.type

    this.closeAll()

    const modal = document.querySelector(
      `.wizard-modal[data-type="${type}"]`
    )

    modal?.classList.remove("hidden")
  }

  close(event) {
    const modal =
      event.currentTarget.closest(".wizard-modal") ||
      event.currentTarget.closest(".wizard-modal-content")?.parentElement

    modal?.classList.add("hidden")
  }

  closeAll() {
    document
      .querySelectorAll(".wizard-modal")
      .forEach(modal => modal.classList.add("hidden"))
  }

  search(event) {
    const query = event.target.value.toLowerCase()
    const modal = event.target.closest(".wizard-modal")

    modal
      .querySelectorAll(".wizard-check-row")
      .forEach(row => {
        row.classList.toggle(
          "hidden",
          !row.textContent.toLowerCase().includes(query)
        )
      })
  }

  toggleService(event) {
    const input = event.target
    const id = input.value

    if (input.checked) {
      this.selected.push({
        id,
        name: input.dataset.name,
        subtype: input.dataset.subtype,
        price: input.dataset.price,
        serviceType: input.dataset.serviceType
      })
    } else {
      this.selected =
        this.selected.filter(item => item.id !== id)
    }

    this.updateSelected()
  }

  updateSelected() {
    if (!this.hasHiddenInputTarget) return

    const container = this.hiddenInputTarget.parentElement

    container
      .querySelectorAll(
        `input[name="${this.inputNameValue}"]`
      )
      .forEach(input => input.remove())

    this.selected.forEach(service => {
      const input = document.createElement("input")

      input.type = "hidden"
      input.name = this.inputNameValue
      input.value = service.id

      container.appendChild(input)
    })

    this.hiddenInputTarget.value = ""

    if (!this.hasSelectedContentTarget) return

    if (this.selected.length === 0) {
      this.selectedContentTarget.classList.add("hidden")
    } else {
      this.selectedContentTarget.classList.remove("hidden")
    }

    this.selectedContentTarget.innerHTML =
      this.selected.map(service => `
        <div class="selected-service-row">
          <button
            type="button"
            class="selected-service-name"
            data-action="click->service-selector#open"
            data-type="service">

            ${service.subtype || service.name}
            (${service.price} ₴)

          </button>

          <button
            type="button"
            class="selected-service-remove"
            data-id="${service.id}"
            data-action="click->service-selector#removeService">

            <img
              src="${this.closeIconValue}"
              class="wiz-icon"
              width="18"
              height="18">

          </button>
        </div>
      `).join("")

    window.dispatchEvent(
      new CustomEvent("service-selector:changed", {
        detail: {
          services: this.selected
        }
      })
    )
  }

  remove(id) {
    const checkbox = document.querySelector(
      `input[type="checkbox"][name="${this.checkboxNameValue}"][value="${id}"]`
    )
    if (checkbox) {
      checkbox.checked = false
    }

    this.selected = this.selected.filter(service => String(service.id) !== String(id))
    this.updateSelected()
  }

  removeService(event) {
    event.stopPropagation()
    this.remove(event.currentTarget.dataset.id)
  }

  removeById(event) {
    this.remove(String(event.detail.id))
  }

  filterCategory(event) {
    const category = event.currentTarget.dataset.category
    const modal = event.currentTarget.closest(".wizard-modal")

    modal
      .querySelectorAll(".filter-chip")
      .forEach(chip => chip.classList.remove("active"))

    event.currentTarget.classList.add("active")

    modal
      .querySelectorAll(".wizard-check-row")
      .forEach(row => {
        const visible =
          category === "all" ||
          row.dataset.category === category

        row.classList.toggle("hidden", !visible)
      })
  }
}

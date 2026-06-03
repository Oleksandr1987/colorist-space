// app/javascript/controllers/service_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["subtype", "categorySelect", "search", "sort", "list", "menu", "unitField", "typeSelect", "type","selected", "toggleButton"]

  static values = {
    categories: Object,
    subtypes: Object,
    addLabel: String,
    saveLabel: String
  }

  connect() {
    this.hasChanges = false
    this.boundOutsideClick = this.handleOutsideClick.bind(this)
    window.addEventListener("click", this.boundOutsideClick)

    this.renderInitialSelected()

    if (this.hasListTarget) {
      this.listTarget.addEventListener("click", () => {
        this.closeMenu()
      })
    }
  }

  disconnect() {
    window.removeEventListener("click", this.boundOutsideClick)
  }

  handleOutsideClick(event) {
    const menu = this.menuTarget
    const toggleButton = this.element.querySelector(".menu-toggle")

    if (menu && toggleButton && !menu.contains(event.target) && !toggleButton.contains(event.target)) {
      this.closeMenu()
    }
  }

  togglePopover(event) {
    const serviceId = event.target.dataset.serviceId
    const popover = document.querySelector(`.popover-menu[data-service-id="${serviceId}"]`)

    document.querySelectorAll(".popover-menu").forEach(p => {
      if (p !== popover) p.classList.add("hidden")
    })

    popover?.classList.toggle("hidden")
    event.stopPropagation()
  }

  toggleMenu() {
    if (!this.menuTarget.classList.contains("hidden") && this.hasChanges) {
      this.closeMenu()

      this.hasChanges = false
      this.toggleButtonTarget.textContent = this.addLabelValue

      return
    }

    this.menuTarget.classList.toggle("hidden")
  }

  closeMenu() {
    this.menuTarget.classList.add("hidden")
  }

  filter() {
    const query = this.searchTarget.value.toLowerCase()

    this.listTarget.querySelectorAll(".service-item").forEach(item => {
      const name = item.dataset.name
      item.classList.toggle("hidden", !name.includes(query))
    })
  }

  sort() {
    const sortValue = this.sortTarget.value
    const items = Array.from(this.listTarget.querySelectorAll(".service-item"))

    let sorted = items

    if (sortValue === "name") {
      sorted = items.sort((a, b) => a.dataset.name.localeCompare(b.dataset.name))
    } else if (sortValue === "price_asc") {
      sorted = items.sort((a, b) => parseInt(a.dataset.price) - parseInt(b.dataset.price))
    } else if (sortValue === "price_desc") {
      sorted = items.sort((a, b) => parseInt(b.dataset.price) - parseInt(a.dataset.price))
    }

    this.listTarget.innerHTML = ""
    sorted.forEach(item => this.listTarget.appendChild(item))

    this.closeMenu()
  }

  normalizeCategory(inputValue) {
    if (!inputValue) return null

    const cleaned = inputValue.trim().toLowerCase()

    for (const key in this.categoriesValue) {
      const translated = this.categoriesValue[key].toLowerCase()
      const english = key.toLowerCase()

      if (cleaned === translated) return key
      if (cleaned === english) return key
    }

    return null
  }

  updateSubtypeOptions(event) {
    const input = event.target.value.trim()
    const key = this.normalizeCategory(input)
    const datalist = document.querySelector("#subtypes")

    datalist.innerHTML = ""

    if (!key) return

    const values = this.subtypesValue[key] || []

    values.forEach(type => {
      const option = document.createElement("option")
      option.value = type
      datalist.appendChild(option)
    })
  }

  toggleUnitField() {
    const selectedType = this.typeSelectTarget.value

    if (selectedType === "preparation" || selectedType === "care_product") {
      this.unitFieldTarget.style.display = ""
    } else {
      this.unitFieldTarget.style.display = "none"
    }
  }

  updateType() {
    if (!this.hasTypeTarget) return

    const checked = Array.from(
      this.element.querySelectorAll("input[type='checkbox']:checked")
    )

    if (checked.length === 0) {
      this.typeTarget.value = ""
      return
    }

    const types = [...new Set(
      checked.map(el => el.dataset.serviceType).filter(Boolean)
    )]

    this.typeTarget.value = types.length === 1 ? types[0] : "combined"
    this.dispatchServicesChanged()
  }

  dispatchServicesChanged() {
    window.dispatchEvent(new CustomEvent("services:changed"))
  }

  toggleService(event) {
    const checkbox = event.target

    const id = checkbox.value
    const name = checkbox.dataset.name
    const price = checkbox.dataset.price

    if (checkbox.checked) {
      this.addSelected(id, name, price)
    } else {
      this.removeSelected(id)
    }

    this.hasChanges = true
    this.toggleButtonTarget.textContent = this.saveLabelValue

    this.dispatchServicesChanged()
  }

  addSelected(id, name, price) {
    const container = this.selectedTarget

    if (container.querySelector(`[data-id="${id}"]`)) return

    const html = `
      <div class="service-item selected" data-id="${id}">
        <div class="service-info">
          <span>${name}</span>
          <span>${price}</span>
        </div>

        <button type="button"
                class="remove"
                data-action="click->service#removeSelected">
          ×
        </button>
      </div>
    `

    container.insertAdjacentHTML("beforeend", html)
  }

  removeSelected(event) {
    const row = event.currentTarget.closest(".service-item")
    const id = row.dataset.id

    const checkbox = document.querySelector(
      `input[name='service_note[service_ids][]'][value='${id}']`
    )
    if (checkbox) checkbox.checked = false

    row.remove()

    this.hasChanges = true
    this.toggleButtonTarget.textContent = this.saveLabelValue

    this.dispatchServicesChanged()
  }

  renderInitialSelected() {
    const checked = this.element.querySelectorAll(
      "input[name='service_note[service_ids][]']:checked"
    )

    checked.forEach(el => {
      this.addSelected(el.value, el.dataset.name, el.dataset.price)
    })
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["subtype", "categorySelect", "search", "sort", "list", "menu", "unitField", "typeSelect"]

  static values = {
    categories: Object,
    subtypes: Object
  }

  connect() {
    this.boundOutsideClick = this.handleOutsideClick.bind(this)
    window.addEventListener("click", this.boundOutsideClick)

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
}

// app/javascript/controllers/service_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["subtype", "categorySelect", "search", "sort", "list", "menu", "unitField", "typeSelect", "type", "selected", "toggleButton"]

  static values = {
    categories: Object,
    subtypes: Object,
    addLabel: String,
    saveLabel: String
  }

  connect() {
    this.boundServicesChanged = this.servicesChanged.bind(this)

    window.addEventListener("service-selector:changed", this.boundServicesChanged)

    this.selectedServices = []
    this.selectedCategories = []

    if (this.hasCategorySelectTarget) {
      this.updateSubtypeOptions()
    }
  }

  disconnect() {
    window.removeEventListener("service-selector:changed", this.boundServicesChanged)
  }

  filter() {
    if (!this.hasListTarget) return

    const query = this.hasSearchTarget ? this.searchTarget.value.trim().toLowerCase() : ""

    this.listTarget.querySelectorAll(".service-item").forEach(item => {
      const name = (item.dataset.name || "").toLowerCase()
      const category = (item.dataset.category || "").trim().toLowerCase()
      const matchesSearch = query === "" || name.includes(query)
      const matchesCategory = this.selectedCategories.length === 0 || this.selectedCategories.includes(category)

      item.classList.toggle("hidden", !(matchesSearch && matchesCategory))
    })
  }

  filterCategory(event) {
    event.preventDefault()

    const category = (event.currentTarget.dataset.category || "").trim().toLowerCase()

    if (category === "") {
      this.selectedCategories = []
    } else if (this.selectedCategories.includes(category)) {
      this.selectedCategories = this.selectedCategories.filter(selectedCategory => selectedCategory !== category)
    } else {
      this.selectedCategories.push(category)
    }

    this.updateCategoryButtons()
    this.filter()
  }

  updateCategoryButtons() {
    this.element
      .querySelectorAll(".care-products-filters .filter-button")
      .forEach(button => {
        const category = (button.dataset.category || "").trim().toLowerCase()
        const active = category === "" ? this.selectedCategories.length === 0 : this.selectedCategories.includes(category)

        button.classList.toggle("active", active)
      })
  }

  servicesChanged(event) {
    this.selectedServices = event.detail.services || []
    this.updateType()
    this.dispatchServicesChanged()
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

  updateSubtypeOptions() {
    if (!this.hasCategorySelectTarget) return

    const input = this.categorySelectTarget.value.trim()
    const key = this.normalizeCategory(input)
    const datalist = this.element.querySelector("#subtypes")

    if (!datalist) return

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

    if (this.selectedServices.length === 0) {
      this.typeTarget.value = ""
      return
    }

    const types = [...new Set(this.selectedServices.map(service => service.serviceType).filter(Boolean))]

    this.typeTarget.value = types.length === 1 ? types[0] : "combined"
  }

  dispatchServicesChanged() {
    window.dispatchEvent(
      new CustomEvent("services:changed", {
        detail: {
          services: this.selectedServices
        }
      })
    )
  }
}

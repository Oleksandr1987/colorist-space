import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["subtype", "categorySelect", "search", "sort", "list", "menu", "unitField", "typeSelect", "type", "selected", "toggleButton", "colorFilters", "oxidantFilters", "formulaAddButton", "formulaBrandFilters"]

  static values = {
    categories: Object,
    subtypes: Object,
    existingSubtypes: Object,
    addLabel: String,
    saveLabel: String,
    formulaFilters: Boolean,
    formulaCategory: String,
    colorNewUrl: String,
    oxidantNewUrl: String
  }

  connect() {
    this.boundServicesChanged = this.servicesChanged.bind(this)

    window.addEventListener("service-selector:changed", this.boundServicesChanged)

    this.selectedServices = []
    this.selectedCategories = []

    this.formulaCategory = this.hasFormulaCategoryValue ? this.formulaCategoryValue : "color"
    this.selectedFormulaBrands = []
    this.selectedFormulaConcentrations = []

    if (this.hasFormulaBrandFiltersTarget) {
      this.formulaBrandFiltersTarget.classList.add("hidden")
    }

    if (this.hasToggleButtonTarget) {
      this.toggleButtonTarget.classList.remove("active")
      this.toggleButtonTarget.setAttribute("aria-expanded", "false")
    }

    if (this.hasCategorySelectTarget) {
      this.updateSubtypeOptions()
    }

    if (this.formulaFiltersValue) {
      this.updateFormulaAddButton()
      this.filterFormulaProducts()
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

    const datalist = this.element.querySelector("#subtypes")
    if (!datalist) return

    const category = this.categorySelectTarget.value.trim()
    const key = this.normalizeCategory(category)

    const defaultSubtypes = key ? (this.subtypesValue[key] || []) : []

    const existingSubtypes = this.existingSubtypesValue[key || category] || []

    const subtypes = [...new Set([...defaultSubtypes, ...existingSubtypes])]

    datalist.replaceChildren()

    subtypes.forEach(subtype => {
      const option = document.createElement("option")
      option.value = subtype
      datalist.appendChild(option)
    })
  }

  // FORMULA CATEGORY
  selectFormulaCategory(event) {
    event.preventDefault()

    this.formulaCategory = event.currentTarget.dataset.formulaCategory
    this.updateFormulaAddButton()
    this.selectedFormulaBrands = []
    this.selectedFormulaConcentrations = []

    this.element
      .querySelectorAll("[data-formula-category]")
      .forEach(button => { button.classList.toggle("active", button.dataset.formulaCategory === this.formulaCategory) })

    this.element
      .querySelectorAll("[data-brand], [data-concentration]")
      .forEach(button => { button.classList.remove("active") })

    if (this.hasColorFiltersTarget) {
      this.colorFiltersTarget.classList.toggle("hidden", this.formulaCategory !== "color")
    }

    if (this.hasOxidantFiltersTarget) {
      this.oxidantFiltersTarget.classList.toggle("hidden", this.formulaCategory !== "oxidant")
    }

    this.filterFormulaProducts()
  }

  updateFormulaAddButton() {
    if (!this.hasFormulaAddButtonTarget) return

    if (this.formulaCategory === "oxidant") {
      this.formulaAddButtonTarget.href = this.oxidantNewUrlValue
    } else {
      this.formulaAddButtonTarget.href = this.colorNewUrlValue
    }
  }

  // FORMULA BRAND
  filterFormulaBrand(event) {
    event.preventDefault()

    const brand = event.currentTarget.dataset.brand

    if (this.selectedFormulaBrands.includes(brand)) {
      this.selectedFormulaBrands = this.selectedFormulaBrands.filter(value => value !== brand)
    } else {
      this.selectedFormulaBrands.push(brand)
    }

    event.currentTarget.classList.toggle("active", this.selectedFormulaBrands.includes(brand))

    this.filterFormulaProducts()
  }

  // OXIDANT CONCENTRATION
  filterFormulaConcentration(event) {
    event.preventDefault()

    const concentration = event.currentTarget.dataset.concentration

    if (this.selectedFormulaConcentrations.includes(concentration)) {
      this.selectedFormulaConcentrations = this.selectedFormulaConcentrations.filter(value => value !== concentration)
    } else {
      this.selectedFormulaConcentrations.push(concentration)
    }

    event.currentTarget.classList.toggle("active", this.selectedFormulaConcentrations.includes(concentration))

    this.filterFormulaProducts()
  }

  // FORMULA PRODUCTS FILTERING
  filterFormulaProducts() {
    if (!this.hasListTarget) return

    const query = this.hasSearchTarget ? this.searchTarget.value.trim().toLowerCase() : ""

    this.listTarget.querySelectorAll(".service-item").forEach(item => {
      const name = (item.dataset.name || "").toLowerCase()
      const category = (item.dataset.category || "").toLowerCase()
      const brand = (item.dataset.brand || "").toLowerCase()
      const concentration = (item.dataset.concentration || "").toLowerCase()
      const matchesCategory = category === this.formulaCategory
      const matchesBrand = this.selectedFormulaBrands.length === 0 || this.selectedFormulaBrands.includes(brand)
      const matchesConcentration = this.formulaCategory !== "oxidant" || this.selectedFormulaConcentrations.length === 0 || this.selectedFormulaConcentrations.includes(concentration)
      const matchesSearch = query === "" || name.includes(query)
      item.classList.toggle( "hidden", !(matchesCategory && matchesBrand && matchesConcentration && matchesSearch))
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

  toggleFormulaFilters(event) {
    event.preventDefault()

    if (!this.hasFormulaBrandFiltersTarget) return

    const isHidden = this.formulaBrandFiltersTarget.classList.toggle("hidden")

    event.currentTarget.classList.toggle("active", !isHidden)
    event.currentTarget.setAttribute("aria-expanded", String(!isHidden))
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

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "modal",
    "from",
    "to",
    "fromDisplay",
    "toDisplay",
    "allTime",
    "incomeServicesSection",
    "incomeServices",
    "allIncomeServices",
    "incomeColors",
    "allColorBrands",
    "allColors",
    "incomeOxidants",
    "allOxidantBrands",
    "allOxidants",
    "incomeCareProducts",
    "allCareBrands",
    "careCategories",
    "allCareCategories",
    "allCareProducts"
  ]

  connect() {
    this.filterIncomeServices()
    this.restoreFormulaBrandSelections()
    this.restoreCareProductSelections()
  }

  open() {
    this.modalTarget.classList.remove("hidden")
    document.body.classList.add("modal-open")
  }

  close() {
    this.modalTarget.classList.add("hidden")
    document.body.classList.remove("modal-open")
  }

  closeOnOverlay(event) {
    if (event.target === this.modalTarget) {
      this.close()
    }
  }

  stopPropagation(event) {
    event.stopPropagation()
  }

  toggleChip(event) {
    const chip = event.currentTarget.closest(".filter-chip")

    if (!chip) return

    chip.classList.toggle("active", event.currentTarget.checked)
  }

  // SERVICES
  toggleIncomeCategory(event) {
    const chip = event.currentTarget.closest(".filter-chip")

    chip?.classList.toggle("active", event.currentTarget.checked)

    this.filterIncomeServices()
  }

  selectAllIncomeCategories() {
    this.element
      .querySelectorAll('input[name="income_categories[]"]')
      .forEach((checkbox) => {
        checkbox.checked = false
        checkbox.closest(".filter-chip")?.classList.remove("active")
      })

    this.clearIncomeServices()
    this.filterIncomeServices()
  }

  filterIncomeServices() {
    if (!this.hasIncomeServicesTarget) return

    const selectedCategories = Array.from(
      this.element.querySelectorAll('input[name="income_categories[]"]:checked')
    ).map((input) => input.value)

    const hasCategories = selectedCategories.length > 0

    if (this.hasIncomeServicesSectionTarget) {
      this.incomeServicesSectionTarget.classList.toggle("hidden", !hasCategories)
    }

    this.element
      .querySelector('[data-action~="click->analytics-filter#selectAllIncomeCategories"]')
      ?.classList.toggle("active", !hasCategories)

    this.incomeServicesTarget
      .querySelectorAll("[data-income-service-category]")
      .forEach((chip) => {
        const visible = hasCategories && selectedCategories.includes(chip.dataset.incomeServiceCategory)

        chip.classList.toggle("hidden", !visible)

        if (!visible) {
          const checkbox = chip.querySelector('input[name="service_ids[]"]')

          if (checkbox) checkbox.checked = false

          chip.classList.remove("active")
        }
      })

    this.updateAllIncomeServices()
  }

  toggleIncomeService(event) {
    this.toggleChip(event)
    this.updateAllIncomeServices()
  }

  selectAllIncomeServices() {
    if (!this.hasIncomeServicesTarget) return

    this.incomeServicesTarget
      .querySelectorAll('[data-income-service-category]:not(.hidden) input[name="service_ids[]"]')
      .forEach((checkbox) => {
        checkbox.checked = false
        checkbox.closest(".filter-chip")?.classList.remove("active")
      })

    this.updateAllIncomeServices()
  }

  clearIncomeServices() {
    if (!this.hasIncomeServicesTarget) return

    this.incomeServicesTarget
      .querySelectorAll('input[name="service_ids[]"]')
      .forEach((checkbox) => {
        checkbox.checked = false
        checkbox.closest(".filter-chip")?.classList.remove("active")
      })
  }

  updateAllIncomeServices() {
    if (!this.hasAllIncomeServicesTarget) return

    const selected =
      this.incomeServicesTarget.querySelector('[data-income-service-category]:not(.hidden) input[name="service_ids[]"]:checked')

    this.allIncomeServicesTarget.classList.toggle("active", !selected)
  }

  // COLORS
  toggleColorBrand(event) {
    this.toggleChip(event)

    if (!event.currentTarget.checked) {
      this.clearFormulaProductsForBrand("color", event.currentTarget.value)
    }

    this.updateFormulaBrandFilter("color")
  }

  selectAllColorBrands() {
    this.element
      .querySelectorAll("[data-color-brand]")
      .forEach((checkbox) => {
        checkbox.checked = false
        checkbox.closest(".filter-chip")?.classList.remove("active")
      })

    this.clearFormulaProducts("color")
    this.updateFormulaBrandFilter("color")
  }

  selectAllColors() {
    this.clearFormulaProducts("color")
    this.updateAllFormulaProducts("color")
  }

  // OXIDANTS
  toggleOxidantBrand(event) {
    this.toggleChip(event)

    if (!event.currentTarget.checked) {
      this.clearFormulaProductsForBrand("oxidant", event.currentTarget.value)
    }

    this.updateFormulaBrandFilter("oxidant")
  }

  selectAllOxidantBrands() {
    this.element
      .querySelectorAll("[data-oxidant-brand]")
      .forEach((checkbox) => {
        checkbox.checked = false
        checkbox.closest(".filter-chip")?.classList.remove("active")
      })

    this.clearFormulaProducts("oxidant")
    this.updateFormulaBrandFilter("oxidant")
  }

  selectAllOxidants() {
    this.clearFormulaProducts("oxidant")
    this.updateAllFormulaProducts("oxidant")
  }

  // FORMULA PRODUCTS
  toggleFormulaProduct(event) {
    this.toggleChip(event)

    const kind = event.currentTarget.dataset.formulaKind

    this.updateAllFormulaProducts(kind)
  }

  updateFormulaBrandFilter(kind) {
    const brandSelector = kind === "color" ? "[data-color-brand]:checked" : "[data-oxidant-brand]:checked"
    const selectedBrands = Array.from(this.element.querySelectorAll(brandSelector)).map((input) => input.value)
    const container = kind === "color" ? this.incomeColorsTarget : this.incomeOxidantsTarget
    const allBrandsTarget = kind === "color" ? this.allColorBrandsTarget : this.allOxidantBrandsTarget
    const productAttribute = kind === "color" ? "data-color-product-brand" : "data-oxidant-product-brand"
    const hasBrands = selectedBrands.length > 0

    allBrandsTarget.classList.toggle("active", !hasBrands)

    container.classList.toggle("hidden", !hasBrands)

    container
      .querySelectorAll(`[${productAttribute}]`)
      .forEach((chip) => {
        const brand = chip.getAttribute(productAttribute)
        const visible = selectedBrands.includes(brand)

        chip.classList.toggle("hidden", !visible)
      })

    this.updateAllFormulaProducts(kind)
  }

  updateAllFormulaProducts(kind) {
    const allTarget = kind === "color" ? this.allColorsTarget : this.allOxidantsTarget

    allTarget.classList.toggle("active", !this.hasSelectedFormulaProducts(kind))
  }

  clearFormulaProducts(kind) {
    this.element
      .querySelectorAll(`input[name="formula_product_ids[]"][data-formula-kind="${kind}"]`)
      .forEach((checkbox) => {
        checkbox.checked = false
        checkbox.closest(".filter-chip")?.classList.remove("active")
      })
  }

  clearFormulaProductsForBrand(kind, brand) {
    const attribute = kind === "color" ? "data-color-product-brand" : "data-oxidant-product-brand"

    this.element
      .querySelectorAll(`[${attribute}="${CSS.escape(brand)}"]`)
      .forEach((chip) => {
        const checkbox = chip.querySelector(`input[name="formula_product_ids[]"][data-formula-kind="${kind}"]`)

        if (checkbox) checkbox.checked = false

        chip.classList.remove("active")
      })
  }

  hasSelectedFormulaProducts(kind) {
    return Boolean(
      this.element.querySelector(`input[name="formula_product_ids[]"][data-formula-kind="${kind}"]:checked`)
    )
  }

  restoreFormulaBrandSelections() {
    this.restoreFormulaBrands("color")
    this.restoreFormulaBrands("oxidant")
  }

  restoreFormulaBrands(kind) {
    const selectedProducts =
      this.element.querySelectorAll(`input[name="formula_product_ids[]"][data-formula-kind="${kind}"]:checked`)

    selectedProducts.forEach((input) => {
      const chip = input.closest(kind === "color" ? "[data-color-product-brand]" : "[data-oxidant-product-brand]")

      if (!chip) return

      const brand = kind === "color" ? chip.dataset.colorProductBrand : chip.dataset.oxidantProductBrand

      const brandCheckbox =
        this.element.querySelector(kind === "color" ? `[data-color-brand="${CSS.escape(brand)}"]` : `[data-oxidant-brand="${CSS.escape(brand)}"]`)

      if (!brandCheckbox) return

      brandCheckbox.checked = true

      brandCheckbox.closest(".filter-chip")?.classList.add("active")
    })

    this.updateFormulaBrandFilter(kind)
  }

  // CARE PRODUCTS

  toggleCareBrand(event) {
    this.toggleChip(event)

    if (!event.currentTarget.checked) {
      this.clearCareProductsForBrand(event.currentTarget.value)
    }

    this.updateCareProductFilter()
  }

  selectAllCareBrands() {
    this.element
      .querySelectorAll("[data-care-brand]")
      .forEach((checkbox) => {
        checkbox.checked = false
        checkbox.closest(".filter-chip")?.classList.remove("active")
      })

    this.clearCareProducts()
    this.updateCareProductFilter()
  }

  toggleCareCategory(event) {
    this.toggleChip(event)

    if (!event.currentTarget.checked) {
      this.clearCareProductsForCategory(event.currentTarget.value)
    }

    this.updateCareProductFilter()
  }

  selectAllCareCategories() {
    this.element
      .querySelectorAll("[data-care-category]")
      .forEach((checkbox) => {
        checkbox.checked = false
        checkbox.closest(".filter-chip")?.classList.remove("active")
      })

    this.clearCareProducts()
    this.updateCareProductFilter()
  }

  selectAllCareProducts() {
    this.clearCareProducts()
    this.updateAllCareProducts()
  }

  toggleCareProduct(event) {
    this.toggleChip(event)
    this.updateAllCareProducts()
  }

  updateCareProductFilter() {
    if (!this.hasIncomeCareProductsTarget) return

    const selectedBrands = Array.from(
      this.element.querySelectorAll("[data-care-brand]:checked")
    ).map((input) => input.value)

    const selectedCategories = Array.from(
      this.element.querySelectorAll("[data-care-category]:checked")
    ).map((input) => input.value)

    const hasBrands = selectedBrands.length > 0
    const hasCategories = selectedCategories.length > 0
    const hasFilter = hasBrands || hasCategories

    if (this.hasAllCareBrandsTarget) {
      this.allCareBrandsTarget.classList.toggle("active", !hasBrands)
    }

    if (this.hasAllCareCategoriesTarget) {
      this.allCareCategoriesTarget.classList.toggle("active", !hasCategories)
    }

    this.incomeCareProductsTarget.classList.toggle("hidden",!hasFilter)

    this.incomeCareProductsTarget
      .querySelectorAll("[data-care-product-brand]")
      .forEach((chip) => {
        const brand = chip.dataset.careProductBrand
        const category = chip.dataset.careProductCategory
        const matchesBrand = !hasBrands || selectedBrands.includes(brand)
        const matchesCategory = !hasCategories ||selectedCategories.includes(category)

        chip.classList.toggle("hidden", !(matchesBrand && matchesCategory))
      })

    this.updateAllCareProducts()
  }

  clearCareProducts() {
    this.element
      .querySelectorAll('input[name="care_product_ids[]"]')
      .forEach((checkbox) => {
        checkbox.checked = false
        checkbox.closest(".filter-chip")?.classList.remove("active")
      })
  }

  clearCareProductsForBrand(brand) {
    this.element
      .querySelectorAll(`[data-care-product-brand="${CSS.escape(brand)}"]`)
      .forEach((chip) => {
        const checkbox = chip.querySelector('input[name="care_product_ids[]"]')

        if (checkbox) checkbox.checked = false

        chip.classList.remove("active")
      })
  }

  clearCareProductsForCategory(category) {
    this.element
      .querySelectorAll(`[data-care-product-category="${CSS.escape(category)}"]`)
      .forEach((chip) => {
        const checkbox = chip.querySelector('input[name="care_product_ids[]"]')

        if (checkbox) checkbox.checked = false

        chip.classList.remove("active")
      })
  }

  updateAllCareProducts() {
    if (!this.hasAllCareProductsTarget) return

    const selected = this.incomeCareProductsTarget.querySelector('input[name="care_product_ids[]"]:checked')

    this.allCareProductsTarget.classList.toggle("active", !selected)
  }

  restoreCareProductSelections() {
    const selectedProducts =
      this.element.querySelectorAll('input[name="care_product_ids[]"]:checked')

    selectedProducts.forEach((input) => {
      const chip = input.closest("[data-care-product-brand]")

      if (!chip) return

      const brand = chip.dataset.careProductBrand
      const category = chip.dataset.careProductCategory
      const brandCheckbox = this.element.querySelector(`[data-care-brand="${CSS.escape(brand)}"]`)
      const categoryCheckbox =this.element.querySelector(`[data-care-category="${CSS.escape(category)}"]`)

      if (brandCheckbox) {
        brandCheckbox.checked = true

        brandCheckbox.closest(".filter-chip")?.classList.add("active")
      }

      if (categoryCheckbox) {
        categoryCheckbox.checked = true

        categoryCheckbox.closest(".filter-chip")?.classList.add("active")
      }
    })

    this.updateCareProductFilter()
  }

  // PERIOD

  selectAllTime(event) {
    this.allTimeTarget.value = "1"

    this.updatePeriodChips(event.currentTarget)
  }

  selectPeriod(event) {
    const input = event.currentTarget

    this.allTimeTarget.value = "0"

    const from = this.formatDate(input.dataset.from)
    const to = this.formatDate(input.dataset.to)

    this.fromTarget.value = from
    this.toTarget.value = to

    this.fromDisplayTarget.value = from
    this.toDisplayTarget.value = to

    this.updatePeriodChips(input)
  }

  fromChanged() {
    this.allTimeTarget.value = "0"
    this.fromTarget.value = this.fromDisplayTarget.value

    this.clearPeriodChips()
  }

  toChanged() {
    this.allTimeTarget.value = "0"
    this.toTarget.value = this.toDisplayTarget.value

    this.clearPeriodChips()
  }

  updatePeriodChips(selectedInput) {
    this.element
      .querySelectorAll('input[type="radio"][name="period"]')
      .forEach((radio) => {
        const selected = radio === selectedInput

        radio.checked = selected

        radio.closest(".filter-chip")?.classList.toggle("active", selected)
      })
  }

  clearPeriodChips() {
    this.element
      .querySelectorAll('input[type="radio"][name="period"]')
      .forEach((radio) => {
        radio.checked = false

        radio.closest(".filter-chip")?.classList.remove("active")
      })
  }

  formatDate(value) {
    const [year, month, day] = value.split("-")

    return `${day}.${month}.${year}`
  }
}

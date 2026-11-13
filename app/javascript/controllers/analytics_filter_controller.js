// app/javascript/controllers/analytics_filter_controller.js
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
    "incomeAdditives",
    "allAdditiveBrands",
    "allAdditives",
    "allOxidantBrands",
    "allOxidants",
    "incomeCareProducts",
    "allCareBrands",
    "careCategories",
    "allCareCategories",
    "allCareProducts"
  ]

  static values = {
    optionsUrl: String,
    defaultFrom: String,
    defaultTo: String
  }

  connect() {
    if (this.hasIncomeServicesTarget) {
      this.filterIncomeServices()
    }

    if (this.hasIncomeColorsTarget) {
      this.restoreFormulaBrands("color")
    }

    if (this.hasIncomeOxidantsTarget) {
      this.restoreFormulaBrands("oxidant")
    }

    if (this.hasIncomeAdditivesTarget) {
      this.restoreFormulaBrands("additive")
    }

    if (this.hasIncomeCareProductsTarget) {
      this.restoreCareProductSelections()
    }

    this.incomeOptionsRequest = null
    this.incomeOptions = null

    this.updateIncomeGroupVisibility()
    this.updateFormulaKindVisibility()
    this.resetDefaultIncomeChips()

    if (this.hasOptionsUrlValue) {
      this.refreshIncomeOptions()
    }
    this.periodSelectedByUser = false
  }

  disconnect() {
    this.incomeOptionsRequest?.abort()
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

    const selectedCategories = [...this.element.querySelectorAll('input[name="income_categories[]"]:checked')].map(input => input.value)
    const hasCategories = selectedCategories.length > 0

    if (this.hasIncomeServicesSectionTarget) {
      this.incomeServicesSectionTarget.classList.toggle("hidden", !hasCategories)
    }

    this.element
      .querySelectorAll('[data-action~="click->analytics-filter#selectAllIncomeCategories"]')
      .forEach(button => button.classList.remove("active"))

    this.incomeServicesTarget
      .querySelectorAll("[data-income-service-category]")
      .forEach(chip => {
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

  // ADDITIVES
  toggleAdditiveBrand(event) {
    this.toggleChip(event)
    if (!event.currentTarget.checked) {
      this.clearFormulaProductsForBrand("additive", event.currentTarget.value)
    }
    this.updateFormulaBrandFilter("additive")
  }

  selectAllAdditiveBrands() {
    this.element.querySelectorAll("[data-additive-brand]").forEach(checkbox => {
      checkbox.checked = false
      checkbox.closest(".filter-chip")?.classList.remove("active")
    })
    this.clearFormulaProducts("additive")
    this.updateFormulaBrandFilter("additive")
  }

  selectAllAdditives() {
    this.clearFormulaProducts("additive")
    this.updateAllFormulaProducts("additive")
  }

  // FORMULA PRODUCTS
  toggleFormulaProduct(event) {
    this.toggleChip(event)

    const kind = event.currentTarget.dataset.formulaKind
    this.updateAllFormulaProducts(kind)
  }

  formulaKindConfig(kind) {
    if (kind === "color" && this.hasIncomeColorsTarget) {
      return { brand: "data-color-brand", productBrand: "data-color-product-brand",
               container: this.incomeColorsTarget, allBrands: this.allColorBrandsTarget,
               allProducts: this.allColorsTarget }
    }
    if (kind === "oxidant" && this.hasIncomeOxidantsTarget) {
      return { brand: "data-oxidant-brand", productBrand: "data-oxidant-product-brand",
               container: this.incomeOxidantsTarget, allBrands: this.allOxidantBrandsTarget,
               allProducts: this.allOxidantsTarget }
    }
    if (kind === "additive" && this.hasIncomeAdditivesTarget) {
      return { brand: "data-additive-brand", productBrand: "data-additive-product-brand",
               container: this.incomeAdditivesTarget, allBrands: this.allAdditiveBrandsTarget,
               allProducts: this.allAdditivesTarget }
    }
    return null
  }

  updateFormulaBrandFilter(kind) {
    const config = this.formulaKindConfig(kind)
    if (!config) return

    const selectedBrands = [...this.element.querySelectorAll(`[${config.brand}]:checked`)]
      .map(input => input.value)
    const hasBrands = selectedBrands.length > 0
    config.allBrands.classList.toggle("active", !hasBrands)
    config.container.classList.toggle("hidden", !hasBrands)

    config.container.querySelectorAll(`[${config.productBrand}]`).forEach(chip => {
      chip.classList.toggle("hidden", !selectedBrands.includes(chip.getAttribute(config.productBrand)))
    })
    this.updateAllFormulaProducts(kind)
  }

  updateAllFormulaProducts(kind) {
    const allTarget = this.formulaKindConfig(kind)?.allProducts
    if (!allTarget) return

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
    const attribute = this.formulaKindConfig(kind)?.productBrand
    if (!attribute) return

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

  restoreFormulaBrands(kind) {
    const config = this.formulaKindConfig(kind)
    if (!config) return

    this.element.querySelectorAll(`input[name="formula_product_ids[]"][data-formula-kind="${kind}"]:checked`)
      .forEach(input => {
        const chip = input.closest(`[${config.productBrand}]`)
        const brand = chip?.getAttribute(config.productBrand)
        if (!brand) return
        const checkbox = [...this.element.querySelectorAll(`[${config.brand}]`)]
          .find(item => item.value === brand)
        if (!checkbox) return
        checkbox.checked = true
        checkbox.closest(".filter-chip")?.classList.add("active")
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

    const selectedBrands = [...this.element.querySelectorAll("[data-care-brand]:checked")].map(input => input.value)
    const availableProducts = this.incomeOptions?.care_products || []
    const availableCategories = new Set(availableProducts.filter(product => selectedBrands.includes(product.brand)).map(product => product.category))
    const categoriesSection = this.element.querySelector("[data-income-care-categories-section]")

    categoriesSection?.classList.toggle("hidden", selectedBrands.length === 0)

    this.element
      .querySelectorAll("[data-care-category]")
      .forEach(input => {
        const chip = input.closest(".filter-chip")
        const available = availableCategories.has(input.value)

        chip?.classList.toggle("hidden", !available)

        if (!available) {
          input.checked = false
          chip?.classList.remove("active")
        }
      })

    const selectedCategories = [...this.element.querySelectorAll("[data-care-category]:checked")].map(input => input.value)
    const showProducts = selectedBrands.length > 0 && selectedCategories.length > 0

    this.incomeCareProductsTarget.classList.toggle("hidden", !showProducts)
    this.incomeCareProductsTarget
      .querySelectorAll("[data-care-product-brand]")
      .forEach(chip => { const matchesBrand = selectedBrands.includes(chip.dataset.careProductBrand)

        const matchesCategory = selectedCategories.includes(chip.dataset.careProductCategory)
        const visible = showProducts && matchesBrand && matchesCategory

        chip.classList.toggle("hidden", !visible)

        const checkbox = chip.querySelector('input[name="care_product_ids[]"]')

        if (checkbox && !visible) {
          checkbox.checked = false
          chip.classList.remove("active")
        }
      })

    if (this.hasAllCareBrandsTarget) {
      this.allCareBrandsTarget.classList.toggle("active", selectedBrands.length === 0)
    }

    if (this.hasAllCareCategoriesTarget) {
      this.allCareCategoriesTarget.classList.toggle("active", selectedCategories.length === 0)
    }

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

    const selected = this.incomeCareProductsTarget.querySelector('[data-care-product-brand]:not(.hidden) input[name="care_product_ids[]"]:checked')

    this.allCareProductsTarget.classList.toggle("active", !selected)
  }

  restoreCareProductSelections() {
    const selectedProducts = this.element.querySelectorAll('input[name="care_product_ids[]"]:checked')

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

    this.updateToMinDate(null)
    this.updatePeriodChips(event.currentTarget)

    this.refreshIncomeOptions()
    this.periodSelectedByUser = true
  }

  selectPeriod(event) {
    const input = event.currentTarget

    this.allTimeTarget.value = "0"

    const from = this.formatDate(input.dataset.from)
    const to = this.formatDate(input.dataset.to)

    this.updateToMinDate(input.dataset.from)

    this.fromTarget.value = from
    this.toTarget.value = to

    this.fromDisplayTarget.value = from
    this.toDisplayTarget.value = to

    this.updatePeriodChips(input)
    this.refreshIncomeOptions()
  }

  fromChanged() {
    this.allTimeTarget.value = "0"

    const from = this.fromDisplayTarget.value

    this.fromTarget.value = from

    const fromIso = this.toIsoDate(from)

    this.updateToMinDate(fromIso)

    if (
      this.toDisplayTarget.value &&
      this.compareDates(this.toDisplayTarget.value, from) < 0
    ) {
      this.toDisplayTarget.value = from
      this.toTarget.value = from
    }

    this.clearPeriodChips()
    this.refreshIncomeOptions()
  }

  toChanged() {
    this.allTimeTarget.value = "0"

    const to = this.toDisplayTarget.value
    this.toTarget.value = to

    this.clearPeriodChips()
    this.refreshIncomeOptions()
  }

  updateToMinDate(value) {
    const element = this.element.querySelector('[data-analytics-filter-datepicker-target="toPicker"]')
    if (!element) return

    const controller = this.application.getControllerForElementAndIdentifier(element, "datepicker")
    controller?.setMinDate(value)
  }

  compareDates(first, second) {
    return this.toIsoDate(first).localeCompare(this.toIsoDate(second))
  }

  toIsoDate(value) {
    if (!value) return ""

    const [day, month, year] = value.split(".")
    return `${year}-${month}-${day}`
  }

  updatePeriodChips(selectedInput) {
    this.element
      .querySelectorAll("[data-period-option]")
      .forEach((radio) => {
        const selected = radio === selectedInput

        radio.checked = selected

        radio.closest(".filter-chip")?.classList.toggle("active", selected)
      })
  }

  clearPeriodChips() {
    this.element
      .querySelectorAll("[data-period-option]")
      .forEach((radio) => {
        radio.checked = false

        radio.closest(".filter-chip")?.classList.remove("active")
      })
  }

  formatDate(value) {
    const [year, month, day] = value.split("-")

    return `${day}.${month}.${year}`
  }

// ===== INCOME GROUPS =====
  toggleIncomeGroup(event) {
    this.toggleChip(event)
    this.updateIncomeGroupVisibility()
  }

  updateIncomeGroupVisibility() {
    const selectedGroups = new Set([...this.element.querySelectorAll("[data-income-group]:checked")].map(input => input.dataset.incomeGroup))

    this.element
      .querySelectorAll("[data-income-group-panel]")
      .forEach(panel => {
        const enabled = selectedGroups.has(panel.dataset.incomeGroupPanel)
        panel.classList.toggle("hidden", !enabled)
        panel.querySelectorAll('input[type="checkbox"]').forEach(input => { input.disabled = !enabled })
      })

    this.updateFormulaKindVisibility()
  }

  // ===== FORMULA KINDS =====
  toggleFormulaKind(event) {
    this.toggleChip(event)
    this.updateFormulaKindVisibility()
  }

  updateFormulaKindVisibility() {
    const formulaEnabled = this.element.querySelector('[data-income-group="formula"]')?.checked === true
    const selectedKinds = new Set([...this.element.querySelectorAll("[data-income-formula-kind]:checked")].map(input => input.dataset.incomeFormulaKind))

    this.element
      .querySelectorAll("[data-income-formula-panel]")
      .forEach(panel => {
        const enabled = formulaEnabled && selectedKinds.has(panel.dataset.incomeFormulaPanel)
        panel.classList.toggle("hidden", !enabled)
        panel.querySelectorAll('input[type="checkbox"]').forEach(input => { input.disabled = !enabled })
      })
  }

  // ===== DYNAMIC PERIOD OPTIONS =====
  async refreshIncomeOptions() {
    if (!this.hasOptionsUrlValue) return

    this.incomeOptionsRequest?.abort()

    const controller = new AbortController()
    this.incomeOptionsRequest = controller

    const url = new URL(this.optionsUrlValue, window.location.origin)
    const allTime = this.hasAllTimeTarget && this.allTimeTarget.value === "1"

    if (allTime) {
      url.searchParams.set("all_time", "1")
    } else {
      const from = this.hasFromTarget && this.fromTarget.value ? this.fromTarget.value : this.formatDate(this.defaultFromValue)

      const to = this.hasToTarget && this.toTarget.value ? this.toTarget.value : this.formatDate(this.defaultToValue)

      if (!from || !to) return

      url.searchParams.set("from", from)
      url.searchParams.set("to", to)
    }

    try {
      const response = await fetch(url, {
        signal: controller.signal,
        headers: { Accept: "application/json" }
      })

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`)
      }

      const options = await response.json()

      if (controller.signal.aborted) return

      if (allTime && this.periodSelectedByUser && options.period) {
        const from = this.formatDate(options.period.from)
        const to = this.formatDate(options.period.to)

        if (this.hasFromTarget) this.fromTarget.value = from
        if (this.hasToTarget) this.toTarget.value = to

        if (this.hasFromDisplayTarget) this.fromDisplayTarget.value = from
        if (this.hasToDisplayTarget) this.toDisplayTarget.value = to
      }

      this.incomeOptions = options
      this.renderIncomeOptions(options)
    } catch (error) {
      if (error.name === "AbortError") return

      console.error("Income filter options:", error)
    }
  }

  renderIncomeOptions(options) {
    this.renderServiceOptions(options.services || [])
    this.renderFormulaOptions("color", options.formula?.colors || [])
    this.renderFormulaOptions("additive", options.formula?.additives || [])
    this.renderFormulaOptions("oxidant", options.formula?.oxidants || [])
    this.renderCareOptions(options.care_products || [])

    this.updateIncomeGroupVisibility()
    this.updateFormulaKindVisibility()
    this.resetDefaultIncomeChips()
  }

  // ===== CHIP HELPERS =====
  createFilterChip({
    name,
    value,
    label,
    checked = false,
    action,
    attributes = {}
  }) {
    const chip = document.createElement("label")
    chip.className = `filter-chip${checked ? " active" : ""}`

    const input = document.createElement("input")
    input.type = "checkbox"
    input.name = name
    input.value = value
    input.checked = checked
    input.dataset.action = action

    Object.entries(attributes).forEach(([key, val]) => { chip.setAttribute(key, String(val)) })

    const text = document.createElement("span")
    text.textContent = label

    chip.append(input, text)

    return chip
  }

  replaceFilterChips(container, chips) {
    if (!container) return

    const existing = new Map([...container.querySelectorAll('input[type="checkbox"]')].map(input => [input.value, input.checked]))
    const allButton = container.querySelector("button.filter-chip")

    container.replaceChildren()

    if (allButton) {
      container.append(allButton)
    }

    chips.forEach(chip => {
      const input = chip.querySelector('input[type="checkbox"]')

      if (input && existing.has(input.value)) {
        input.checked = existing.get(input.value)
        chip.classList.toggle("active", input.checked)
      }

      container.append(chip)
    })
  }

  resetDefaultIncomeChips() {
    const selectedGroups = this.element.querySelectorAll("[data-income-group]:checked")

    if (selectedGroups.length > 0) return

    this.element.querySelectorAll('[data-income-group-panel] button.filter-chip').forEach(button => {
      button.classList.remove("active")
    })
  }

  // ===== SERVICE OPTIONS =====
  renderServiceOptions(services) {
    const categoriesContainer = this.element.querySelector("[data-income-service-categories]")

    if (!categoriesContainer || !this.hasIncomeServicesTarget) return

    const categories = [...new Set(services.map(service => service.category).filter(Boolean))]

    const categoryLabels = new Map(
      [...categoriesContainer.querySelectorAll('input[name="income_categories[]"]')]
      .map(input => [input.value, input.closest("label")?.querySelector("span")?.textContent?.trim()])
    )

    this.replaceFilterChips(
      categoriesContainer,
      categories.map(category => this.createFilterChip({
        name: "income_categories[]",
        value: category,
        label: categoryLabels.get(category) || category,
        action: "change->analytics-filter#toggleIncomeCategory",
        attributes: { "data-income-category-option": category }
      }))
    )

    this.replaceFilterChips(
      this.incomeServicesTarget,
      services.map(service => this.createFilterChip({
        name: "service_ids[]",
        value: service.id,
        label: service.label,
        action: "change->analytics-filter#toggleIncomeService",
        attributes: { "data-income-service-category": service.category }
      }))
    )

    this.filterIncomeServices()
  }

  // ===== FORMULA OPTIONS =====
  renderFormulaOptions(kind, products) {
    const config = {
      color: {
        brand: "data-color-brand",
        productBrand: "data-color-product-brand",
        target: "incomeColors",
        action: "toggleColorBrand"
      },
      additive: {
        brand: "data-additive-brand",
        productBrand: "data-additive-product-brand",
        target: "incomeAdditives",
        action: "toggleAdditiveBrand"
      },
      oxidant: {
        brand: "data-oxidant-brand",
        productBrand: "data-oxidant-product-brand",
        target: "incomeOxidants",
        action: "toggleOxidantBrand"
      }
    }[kind]

    if (!config) return

    const panel = this.element.querySelector(`[data-income-formula-panel="${kind}"]`)

    if (!panel) return

    const brandContainer = panel.querySelector("[data-income-formula-brands]")
    const productContainer = this[`${config.target}Target`]

    if (!brandContainer || !productContainer) return

    const brands = [...new Set(products.map(product => product.brand).filter(Boolean))].sort()

    this.replaceFilterChips(
      brandContainer,
      brands.map(brand => this.createFilterChip({
        name: `income_ui_${kind}_brands[]`,
        value: brand,
        label: brand,
        action: `change->analytics-filter#${config.action}`,
        attributes: { [config.brand]: brand }
      }))
    )

    this.replaceFilterChips(
      productContainer,
      products.map(product => this.createFilterChip({
        name: "formula_product_ids[]",
        value: product.id,
        label: product.label,
        action: "change->analytics-filter#toggleFormulaProduct",
        attributes: { [config.productBrand]: product.brand, "data-formula-kind": kind }
      }))
    )

    this.restoreFormulaBrands(kind)
  }

  // ===== CARE OPTIONS =====
  renderCareOptions(products) {
    const brandsContainer = this.element.querySelector("[data-income-care-brands]")
    const categoriesContainer = this.element.querySelector("[data-income-care-categories]")
    const productsContainer = this.element.querySelector("[data-income-care-products]")
    if (!brandsContainer || !categoriesContainer || !productsContainer) {
      return
    }

    const brands = [...new Set(products.map(product => product.brand).filter(Boolean))].sort()

    const categories = [...new Set(products.map(product => product.category).filter(Boolean))].sort()

    const categoryLabels = new Map(
      [...categoriesContainer.querySelectorAll("[data-care-category]")]
        .map(input => [input.value, input.closest("label")?.querySelector("span")?.textContent?.trim()])
    )

    this.replaceFilterChips(
      brandsContainer,
      brands.map(brand => this.createFilterChip({
        name: "income_ui_care_brands[]",
        value: brand,
        label: brand,
        action: "change->analytics-filter#toggleCareBrand",
        attributes: { "data-care-brand": brand }
      }))
    )

    this.replaceFilterChips(
      categoriesContainer,
      categories.map(category => this.createFilterChip({
        name: "income_ui_care_categories[]",
        value: category,
        label: categoryLabels.get(category) || category,
        action: "change->analytics-filter#toggleCareCategory",
        attributes: { "data-care-category": category }
      }))
    )

    this.replaceFilterChips(
      productsContainer,
      products.map(product => this.createFilterChip({
        name: "care_product_ids[]",
        value: product.id,
        label: product.label,
        action: "change->analytics-filter#toggleCareProduct",
        attributes: { "data-care-product-brand": product.brand, "data-care-product-category": product.category }
      }))
    )

    this.restoreCareProductSelections()
  }
}

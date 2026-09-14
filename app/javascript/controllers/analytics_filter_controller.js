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
    "allOxidants"
  ]

  connect() {
    this.filterIncomeServices()
    this.restoreFormulaBrandSelections()
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
      this.element.querySelectorAll(
        'input[name="income_categories[]"]:checked'
      )
    ).map((input) => input.value)

    const hasCategories = selectedCategories.length > 0

    if (this.hasIncomeServicesSectionTarget) {
      this.incomeServicesSectionTarget.classList.toggle(
        "hidden",
        !hasCategories
      )
    }

    this.element
      .querySelector('[data-action~="click->analytics-filter#selectAllIncomeCategories"]')
      ?.classList.toggle("active", !hasCategories)

    this.incomeServicesTarget
      .querySelectorAll("[data-income-service-category]")
      .forEach((chip) => {
        const visible =
          hasCategories &&
          selectedCategories.includes(
            chip.dataset.incomeServiceCategory
          )

        chip.classList.toggle("hidden", !visible)

        if (!visible) {
          const checkbox =
            chip.querySelector('input[name="service_ids[]"]')

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
      .querySelectorAll(
        '[data-income-service-category]:not(.hidden) input[name="service_ids[]"]'
      )
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
      this.incomeServicesTarget.querySelector(
        '[data-income-service-category]:not(.hidden) input[name="service_ids[]"]:checked'
      )

    this.allIncomeServicesTarget.classList.toggle(
      "active",
      !selected
    )
  }

  // COLORS

  selectAllColorBrands() {
    this.clearBrandButtons("color")
    this.clearFormulaProducts("color")

    if (this.hasAllColorBrandsTarget) {
      this.allColorBrandsTarget.classList.add("active")
    }

    if (this.hasIncomeColorsTarget) {
      this.incomeColorsTarget.classList.add("hidden")
    }
  }

  selectColorBrand(event) {
    const brand = event.currentTarget.dataset.colorBrand

    this.clearBrandButtons("color")
    event.currentTarget.classList.add("active")

    if (this.hasAllColorBrandsTarget) {
      this.allColorBrandsTarget.classList.remove("active")
    }

    this.filterFormulaProducts("color", brand)
  }

  selectAllColors() {
    this.clearFormulaProducts("color")

    if (this.hasAllColorsTarget) {
      this.allColorsTarget.classList.add("active")
    }
  }

  // OXIDANTS

  selectAllOxidantBrands() {
    this.clearBrandButtons("oxidant")
    this.clearFormulaProducts("oxidant")

    if (this.hasAllOxidantBrandsTarget) {
      this.allOxidantBrandsTarget.classList.add("active")
    }

    if (this.hasIncomeOxidantsTarget) {
      this.incomeOxidantsTarget.classList.add("hidden")
    }
  }

  selectOxidantBrand(event) {
    const brand = event.currentTarget.dataset.oxidantBrand

    this.clearBrandButtons("oxidant")
    event.currentTarget.classList.add("active")

    if (this.hasAllOxidantBrandsTarget) {
      this.allOxidantBrandsTarget.classList.remove("active")
    }

    this.filterFormulaProducts("oxidant", brand)
  }

  selectAllOxidants() {
    this.clearFormulaProducts("oxidant")

    if (this.hasAllOxidantsTarget) {
      this.allOxidantsTarget.classList.add("active")
    }
  }

  toggleFormulaProduct(event) {
    this.toggleChip(event)

    const kind = event.currentTarget.dataset.formulaKind

    if (kind === "color" && this.hasAllColorsTarget) {
      this.allColorsTarget.classList.toggle(
        "active",
        !this.hasSelectedFormulaProducts("color")
      )
    }

    if (kind === "oxidant" && this.hasAllOxidantsTarget) {
      this.allOxidantsTarget.classList.toggle(
        "active",
        !this.hasSelectedFormulaProducts("oxidant")
      )
    }
  }

  filterFormulaProducts(kind, brand) {
    const container =
      kind === "color"
        ? this.incomeColorsTarget
        : this.incomeOxidantsTarget

    container.classList.remove("hidden")

    const attribute =
      kind === "color"
        ? "data-color-product-brand"
        : "data-oxidant-product-brand"

    container
      .querySelectorAll(`[${attribute}]`)
      .forEach((chip) => {
        const visible =
          chip.getAttribute(attribute) === brand

        chip.classList.toggle("hidden", !visible)

        if (!visible) {
          const checkbox =
            chip.querySelector(
              'input[name="formula_product_ids[]"]'
            )

          if (checkbox) checkbox.checked = false

          chip.classList.remove("active")
        }
      })

    const allTarget =
      kind === "color"
        ? this.allColorsTarget
        : this.allOxidantsTarget

    allTarget.classList.toggle(
      "active",
      !this.hasSelectedFormulaProducts(kind)
    )
  }

  clearFormulaProducts(kind) {
    this.element
      .querySelectorAll(
        `input[name="formula_product_ids[]"][data-formula-kind="${kind}"]`
      )
      .forEach((checkbox) => {
        checkbox.checked = false
        checkbox.closest(".filter-chip")?.classList.remove("active")
      })
  }

  hasSelectedFormulaProducts(kind) {
    return Boolean(
      this.element.querySelector(
        `input[name="formula_product_ids[]"][data-formula-kind="${kind}"]:checked`
      )
    )
  }

  clearBrandButtons(kind) {
    const attribute =
      kind === "color"
        ? "[data-color-brand]"
        : "[data-oxidant-brand]"

    this.element
      .querySelectorAll(attribute)
      .forEach((button) => {
        button.classList.remove("active")
      })
  }

  restoreFormulaBrandSelections() {
    this.restoreFormulaBrandSelection("color")
    this.restoreFormulaBrandSelection("oxidant")
  }

  restoreFormulaBrandSelection(kind) {
    const selected =
      this.element.querySelector(
        `input[name="formula_product_ids[]"][data-formula-kind="${kind}"]:checked`
      )

    if (!selected) return

    const chip = selected.closest(
      kind === "color"
        ? "[data-color-product-brand]"
        : "[data-oxidant-product-brand]"
    )

    if (!chip) return

    const brand =
      kind === "color"
        ? chip.dataset.colorProductBrand
        : chip.dataset.oxidantProductBrand

    const brandButton =
      this.element.querySelector(
        kind === "color"
          ? `[data-color-brand="${CSS.escape(brand)}"]`
          : `[data-oxidant-brand="${CSS.escape(brand)}"]`
      )

    if (brandButton) {
      if (kind === "color" && this.hasAllColorBrandsTarget) {
        this.allColorBrandsTarget.classList.remove("active")
      }

      if (kind === "oxidant" && this.hasAllOxidantBrandsTarget) {
        this.allOxidantBrandsTarget.classList.remove("active")
      }

      brandButton.classList.add("active")
      this.filterFormulaProducts(kind, brand)
    }
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

        radio.closest(".filter-chip")
          ?.classList.toggle("active", selected)
      })
  }

  clearPeriodChips() {
    this.element
      .querySelectorAll('input[type="radio"][name="period"]')
      .forEach((radio) => {
        radio.checked = false

        radio.closest(".filter-chip")
          ?.classList.remove("active")
      })
  }

  formatDate(value) {
    const [year, month, day] = value.split("-")

    return `${day}.${month}.${year}`
  }
}

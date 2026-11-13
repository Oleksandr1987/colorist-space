// app/javascript/controllers/appointments_filter_controller.js

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "from", "to", "fromDisplay", "toDisplay", "allTime", "categories", "servicesSection", "services"]

  static values = {
    firstDate: String,
    lastDate: String,
    optionsUrl: String
  }

  connect() {
    this.handleEscape = this.handleEscape.bind(this)
    this.resetSelection()
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleEscape)
    document.body.classList.remove("modal-open")
  }

  // MODAL
  open() {
    this.resetSelection()
    this.updateChips()
    this.restorePeriod()
    this.refreshFilterOptions()

    this.modalTarget.classList.remove("hidden")
    document.body.classList.add("modal-open")
    document.addEventListener("keydown", this.handleEscape)
  }

  close() {
    this.modalTarget.classList.add("hidden")
    document.body.classList.remove("modal-open")
    document.removeEventListener("keydown", this.handleEscape)

    this.resetSelection()
    this.updateChips()
    this.restorePeriod()
  }

  closeOnOverlay(event) {
    if (event.target === this.modalTarget) this.close()
  }

  handleEscape(event) {
    if (event.key === "Escape") this.close()
  }

  // INITIAL STATE
  resetSelection() {
    const params = new URLSearchParams(window.location.search)

    this.selected = {
      categories: this.paramValues(params, "categories"),
      service_ids: this.paramValues(params, "service_ids")
    }
  }

  paramValues(params, name) {
    return [...params.getAll(name), ...params.getAll(`${name}[]`)]
  }

  // PERIOD
  setDisplayDate(target, value) {
    const controller = this.application.getControllerForElementAndIdentifier(target, "datepicker")

    if (controller) {
      controller.setDate(value)
    } else {
      target.value = value
    }
  }
  selectAllTime(event) {
    this.allTimeTarget.value = "1"

    const from = this.hasFirstDateValue ? this.formatDate(this.firstDateValue) : ""
    const to = this.hasLastDateValue ? this.formatDate(this.lastDateValue) : ""

    this.fromTarget.value = from
    this.toTarget.value = to

    this.setDisplayDate(this.fromDisplayTarget, from)
    this.setDisplayDate(this.toDisplayTarget, to)
    this.updateToMinDate(null)
    this.updatePeriodChips(event.currentTarget)
    this.refreshFilterOptions()
  }

  selectPeriod(event) {
    const input = event.currentTarget
    const from = this.formatDate(input.dataset.from)
    const to = this.formatDate(input.dataset.to)

    this.allTimeTarget.value = "0"
    this.fromTarget.value = from
    this.toTarget.value = to

    this.setDisplayDate(this.fromDisplayTarget, from)
    this.setDisplayDate(this.toDisplayTarget, to)
    this.updateToMinDate(input.dataset.from)
    this.updatePeriodChips(input)
    this.refreshFilterOptions()
  }

  fromChanged() {
    const from = this.fromDisplayTarget.value

    this.allTimeTarget.value = "0"
    this.fromTarget.value = from
    this.updateToMinDate(this.toIsoDate(from))

    if (
      this.toDisplayTarget.value &&
      this.compareDates(this.toDisplayTarget.value, from) < 0
    ) {
      this.toDisplayTarget.value = from
      this.toTarget.value = from
    }

    this.clearPeriodChips()
    this.refreshFilterOptions()
  }

  toChanged() {
    this.allTimeTarget.value = "0"
    this.toTarget.value = this.toDisplayTarget.value

    this.clearPeriodChips()
    this.refreshFilterOptions()
  }

  updateToMinDate(value) {
    const element = this.toDisplayTarget
    const controller = this.application.getControllerForElementAndIdentifier(element, "datepicker")

    controller?.setMinDate(value)
  }

  restorePeriod() {
    const initialFrom = this.fromTarget.defaultValue
    const initialTo = this.toTarget.defaultValue
    const initialAllTime = this.allTimeTarget.defaultValue

    this.fromTarget.value = initialFrom
    this.toTarget.value = initialTo
    this.allTimeTarget.value = initialAllTime

    this.fromDisplayTarget.value = initialFrom
    this.toDisplayTarget.value = initialTo

    this.updateToMinDate(this.toIsoDate(initialFrom))

    const radios = this.modalTarget.querySelectorAll("[data-period-option]")

    radios.forEach(radio => {
      let active = false

      if (radio.value === "all") {
        active = initialAllTime === "1"
      } else if (initialFrom && initialTo && initialAllTime !== "1") {
        active =
          this.formatDate(radio.dataset.from) === initialFrom &&
          this.formatDate(radio.dataset.to) === initialTo
      }

      radio.checked = active
      radio.closest(".filter-chip")?.classList.toggle("active", active)
    })
  }

  updatePeriodChips(selectedInput) {
    this.modalTarget
      .querySelectorAll("[data-period-option]")
      .forEach(radio => {
        const active = radio === selectedInput

        radio.checked = active
        radio.closest(".filter-chip")?.classList.toggle("active", active)
      })
  }

  clearPeriodChips() {
    this.modalTarget
      .querySelectorAll("[data-period-option]")
      .forEach(radio => {
        radio.checked = false
        radio.closest(".filter-chip")?.classList.remove("active")
      })
  }

  formatDate(value) {
    if (!value) return ""

    const [year, month, day] = value.split("-")
    return `${day}.${month}.${year}`
  }

  toIsoDate(value) {
    if (!value) return ""

    const [day, month, year] = value.split(".")
    return `${year}-${month}-${day}`
  }

  compareDates(first, second) {
    return this.toIsoDate(first).localeCompare(this.toIsoDate(second))
  }


  // CATEGORIES AND SERVICES
  toggleSelection(event) {
    const button = event.currentTarget
    const { filterGroup: group, filterValue: value } = button.dataset

    if (!value || !Array.isArray(this.selected[group])) return

    const values = this.selected[group]

    if (values.includes(value)) {
      this.selected[group] = values.filter(item => item !== value)
    } else {
      this.selected[group] = [...values, value]
    }

    if (group === "categories") {
      this.selected.service_ids = []
    }

    this.updateChips()
  }

  clearSelection(event) {
    const group = event.currentTarget.dataset.filterGroup

    if (!Array.isArray(this.selected[group])) return

    this.selected[group] = []

    if (group === "categories") {
      this.selected.service_ids = []
    }

    this.updateChips()
  }


  updateChips() {
    const categories = this.selected.categories

    this.modalTarget
      .querySelectorAll("[data-filter-group]")
      .forEach(button => {
        const { filterGroup: group, filterValue: value } = button.dataset
        const selected = this.selected[group]

        if (!Array.isArray(selected)) return

        const active = value === "" ? selected.length === 0 : selected.includes(value)

        button.classList.toggle("active", active)
        button.setAttribute("aria-pressed", String(active))
      })

    this.servicesSectionTarget.classList.remove("hidden")
    this.servicesTarget
      .querySelectorAll("[data-service-category]")
      .forEach(button => {
        const category = button.dataset.serviceCategory

        const visible =
          !button.classList.contains("period-unavailable") &&
          (categories.length === 0 || categories.includes(category))

        button.classList.toggle("hidden", !visible)
      })

    const allowedIds = Array.from(this.servicesTarget.querySelectorAll("[data-service-category]"))
      .filter(button => categories.length === 0 || categories.includes(button.dataset.serviceCategory))
      .map(button => button.dataset.filterValue)

    this.selected.service_ids = this.selected.service_ids.filter(id => allowedIds.includes(id))

    this.servicesTarget
      .querySelectorAll("[data-filter-value]")
      .forEach(button => {
        const value = button.dataset.filterValue
        const active = value === "" ? this.selected.service_ids.length === 0 : this.selected.service_ids.includes(value)

        button.classList.toggle("active", active)
        button.setAttribute("aria-pressed", String(active))
      })
  }

  async refreshFilterOptions() {
    const url = new URL(this.optionsUrlValue, window.location.origin)

    if (this.allTimeTarget.value === "1") {
      url.searchParams.set("all_time", "1")
    } else {
      if (this.fromTarget.value) {
        url.searchParams.set("from", this.fromTarget.value)
      }

      if (this.toTarget.value) {
        url.searchParams.set("to", this.toTarget.value)
      }
    }

    const response = await fetch(url, { headers: { Accept: "application/json" } })

    if (!response.ok) return

    const data = await response.json()
    const availableCategories = new Set(data.categories)
    const availableServices = new Set(data.services.map(service => String(service.id)))

    this.categoriesTarget
      .querySelectorAll("[data-filter-value]")
      .forEach(button => {
        const value = button.dataset.filterValue

        button.classList.toggle("hidden", value !== "" && !availableCategories.has(value))
      })

    this.servicesTarget
      .querySelectorAll("[data-service-category]")
      .forEach(button => {
        const id = button.dataset.filterValue

        button.classList.toggle("period-unavailable", !availableServices.has(id))
      })

    this.selected.categories = this.selected.categories.filter(category => availableCategories.has(category))
    this.selected.service_ids = this.selected.service_ids.filter(id => availableServices.has(id))

    this.updateChips()
  }

  // APPLY
  apply(event) {
    event.preventDefault()

    const url = new URL(window.location.href)
    const filterParams = ["year", "month", "from", "to", "all_time", "categories", "service_ids"]

    filterParams.forEach(param => {
      url.searchParams.delete(param)
      url.searchParams.delete(`${param}[]`)
    })

    if (this.allTimeTarget.value === "1") {
      url.searchParams.set("all_time", "1")
    } else {
      if (this.fromTarget.value) {
        url.searchParams.set("from", this.fromTarget.value)
      }

      if (this.toTarget.value) {
        url.searchParams.set("to", this.toTarget.value)
      }
    }

    this.selected.categories.forEach(category => {
      url.searchParams.append("categories[]", category)
    })

    this.selected.service_ids.forEach(id => {
      url.searchParams.append("service_ids[]", id)
    })

    window.location.assign(url.toString())
  }


  // DASHBOARD ACTIONS
  clearPeriodParams(url) {
    ["year", "month", "from", "to", "all_time"].forEach(param => {
      url.searchParams.delete(param)
    })
  }

  showAllYears() {
    const url = new URL(window.location.href)

    this.clearPeriodParams(url)

    window.location.assign(url.toString())
  }

  filterYear(event) {
    const url = new URL(window.location.href)

    this.clearPeriodParams(url)

    url.searchParams.set("year", event.currentTarget.dataset.year)

    window.location.assign(url.toString())
  }

  filterMonth(event) {
    const url = new URL(window.location.href)

    this.clearPeriodParams(url)

    url.searchParams.set("year", event.currentTarget.dataset.year)
    url.searchParams.set("month", event.currentTarget.dataset.month)

    window.location.assign(url.toString())
  }
}

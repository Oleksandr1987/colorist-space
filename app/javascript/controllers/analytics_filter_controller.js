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
    "incomeServices"
  ]

  connect() {
    this.filterIncomeServices()
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

  toggleIncomeCategory(event) {
    const chip = event.currentTarget.closest(".filter-chip")

    chip?.classList.toggle("active", event.currentTarget.checked)

    this.filterIncomeServices()
  }

  filterIncomeServices() {
    if (!this.hasIncomeServicesTarget) return

    const selectedCategories = Array.from(
      this.element.querySelectorAll(
        'input[name="income_categories[]"]:checked'
      )
    ).map((input) => input.value)

    const serviceChips =
      this.incomeServicesTarget.querySelectorAll(
        "[data-income-service-category]"
      )

    serviceChips.forEach((chip) => {
      const category = chip.dataset.incomeServiceCategory

      const visible =
        selectedCategories.length === 0 ||
        selectedCategories.includes(category)

      chip.classList.toggle("hidden", !visible)

      if (!visible) {
        const checkbox =
          chip.querySelector('input[name="service_ids[]"]')

        if (checkbox) {
          checkbox.checked = false
        }

        chip.classList.remove("active")
      }
    })
  }

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
      .querySelectorAll('.filter-chips input[type="radio"]')
      .forEach((radio) => {
        radio.closest(".filter-chip")
          ?.classList.toggle("active", radio === selectedInput)
      })
  }

  clearPeriodChips() {
    this.element
      .querySelectorAll('.filter-chips input[type="radio"]')
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

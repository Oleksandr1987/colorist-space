// app/javascript/controllers/appointments_filter_controller.js

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  // -----------------------
  // Dashboard
  // -----------------------

  showAllYears() {
    const url = new URL(window.location)

    url.searchParams.delete("year")
    url.searchParams.delete("month")

    window.location = url
  }

  filterYear(event) {
    const year = event.currentTarget.dataset.year
    const url = new URL(window.location)

    url.searchParams.set("year", year)
    url.searchParams.delete("month")

    window.location = url
  }

  filterMonth(event) {
    const year = event.currentTarget.dataset.year
    const month = event.currentTarget.dataset.month
    const url = new URL(window.location)

    url.searchParams.set("year", year)
    url.searchParams.set("month", month)

    window.location = url
  }

  // -----------------------
  // Multi-select filters
  // -----------------------

  toggleFilter(event) {
    const button = event.currentTarget
    const param = button.dataset.param
    const value = button.dataset.value
    const url = new URL(window.location)
    const values = url.searchParams.getAll(param)

    if (values.includes(value)) {
      url.searchParams.delete(param)

      values
        .filter(v => v !== value)
        .forEach(v => url.searchParams.append(param, v))
    } else {
      url.searchParams.append(param, value)
    }

    if (param === "categories") {
      url.searchParams.delete("service_ids")
    }

    window.location = url
  }

  clearFilter(event) {
    const button = event.currentTarget
    const param = button.dataset.param
    const url = new URL(window.location)

    url.searchParams.delete(param)

    if (param === "categories") {
      url.searchParams.delete("service_ids")
    }

    window.location = url
  }
}

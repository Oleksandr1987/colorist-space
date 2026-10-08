// app/javascript/controllers/appointments_filter_controller.js

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
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

  toggleFilter(event) {
    const button = event.currentTarget
    const param = button.dataset.param
    const queryParam = `${param}[]`
    const value = button.dataset.value
    const url = new URL(window.location)

    const values = [
      ...url.searchParams.getAll(queryParam),
      ...url.searchParams.getAll(param)
    ]

    url.searchParams.delete(param)
    url.searchParams.delete(queryParam)

    if (values.includes(value)) {
      values
        .filter(item => item !== value)
        .forEach(item => url.searchParams.append(queryParam, item))
    } else {
      values
        .concat(value)
        .forEach(item => url.searchParams.append(queryParam, item))
    }

    if (param === "categories") {
      url.searchParams.delete("service_ids")
      url.searchParams.delete("service_ids[]")
    }

    window.location = url
  }

  clearFilter(event) {
    const button = event.currentTarget
    const param = button.dataset.param
    const queryParam = `${param}[]`
    const url = new URL(window.location)

    url.searchParams.delete(param)
    url.searchParams.delete(queryParam)

    if (param === "categories") {
      url.searchParams.delete("service_ids")
      url.searchParams.delete("service_ids[]")
    }

    window.location = url
  }
}

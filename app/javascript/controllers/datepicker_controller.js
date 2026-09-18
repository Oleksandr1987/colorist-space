// app/javascript/controllers/datepicker_controller.js
import { Controller } from "@hotwired/stimulus"
import "litepicker"

export default class extends Controller {
  static targets = ["input"]

  connect() {
    this.inputTargets.forEach((input) => {
      const form = input.closest("form")
      const originalName = input.getAttribute("name")
      const displayValue = input.value.trim()

      if (originalName) {
        input.removeAttribute("name")

        if (displayValue.match(/^\d{2}\.\d{2}\.\d{4}$/)) {
          const hidden = document.createElement("input")
          hidden.type = "hidden"
          hidden.name = originalName
          hidden.value = displayValue.split(".").reverse().join("-")
          form.appendChild(hidden)
        }
      }

      new window.Litepicker({
        element: input,
        format: "DD.MM.YYYY",
        lang: "uk",

        dropdowns: {
          minYear: 2020,
          maxYear: new Date().getFullYear() + 1,
          months: true,
          years: true,
        },

        minDate: this.getMinDate(input),
        maxDate: this.getMaxDate(input),

        setup: (picker) => {
          picker.on("selected", (date) => {
            input.value = date.format("DD.MM.YYYY")

            if (originalName) {
              const existing = form?.querySelector(
                `input[type="hidden"][name="${originalName}"]`
              )

              if (existing) existing.remove()

              const hidden = document.createElement("input")
              hidden.type = "hidden"
              hidden.name = originalName
              hidden.value = date.format("YYYY-MM-DD")
              form?.appendChild(hidden)
            }

            input.dispatchEvent(
              new CustomEvent("datepicker:selected", {
                bubbles: true
              })
            )
          })
        },
      })
    })
  }

  getMinDate(input) {
    const minAttr = input.dataset.min || input.getAttribute("min")
    return minAttr ? new Date(minAttr) : null
  }

  getMaxDate(input) {
    const maxAttr = input.getAttribute("max")
    return maxAttr ? new Date(maxAttr) : null
  }
}

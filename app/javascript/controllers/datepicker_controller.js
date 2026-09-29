// app/javascript/controllers/datepicker_controller.js
import { Controller } from "@hotwired/stimulus"
import "litepicker"

export default class extends Controller {
  connect() {
    const input = this.element
    const form = input.closest("form")
    const originalName = input.getAttribute("name")
    const displayValue = input.value.trim()

    if (originalName) {
      input.removeAttribute("name")

      let hiddenValue = null

      if (/^\d{2}\.\d{2}\.\d{4}$/.test(displayValue)) {
        hiddenValue = displayValue.split(".").reverse().join("-")
      } else if (/^\d{4}-\d{2}-\d{2}$/.test(displayValue)) {
        hiddenValue = displayValue
        input.value = displayValue.split("-").reverse().join(".")
      }

      if (hiddenValue) {
        this.createHiddenInput(form, originalName, hiddenValue)
      }
    }

    const parentSelector = input.dataset.datepickerParent
    const parentEl = parentSelector ? input.closest(parentSelector) : undefined

    this.picker = new window.Litepicker({
      element: input,
      parentEl: parentEl,
      format: "DD.MM.YYYY",
      lang: "uk",
      autoApply: true,

      dropdowns: {
        minYear: 2020,
        maxYear: new Date().getFullYear(),
        months: true,
        years: true,
      },

      minDate: this.getMinDate(input),
      maxDate: this.getMaxDate(input),

      setup: (picker) => {
        picker.on("selected", (date) => {
          input.value = date.format("DD.MM.YYYY")

          if (originalName) {
            this.createHiddenInput(form, originalName, date.format("YYYY-MM-DD"))
          }

          input.dispatchEvent(new CustomEvent("datepicker:selected", { bubbles: true }))
        })
      },
    })
  }

  disconnect() {
    this.picker?.destroy()
  }

  setMinDate(value) {
    this.picker?.setOptions({ minDate: value || null })
  }

  setMaxDate(value) {
    this.picker?.setOptions({ maxDate: value || null })
  }

  createHiddenInput(form, name, value) {
    if (!form) return
    form.querySelector(`input[type="hidden"][name="${name}"]`)?.remove()

    const hidden = document.createElement("input")

    hidden.type = "hidden"
    hidden.name = name
    hidden.value = value

    form.appendChild(hidden)
  }

  getMinDate(input) {
    return input.dataset.min || input.getAttribute("min") || null
  }

  getMaxDate(input) {
    return input.dataset.max || input.getAttribute("max") || null
  }
}

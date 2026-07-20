// app/javascript/controllers/datepicker_controller.js
import { Controller } from "@hotwired/stimulus"
import "litepicker"

export default class extends Controller {
  static targets = ["input"]

  connect() {
    this.inputTargets.forEach(input => {
      const form = input.closest("form")
      const originalName = input.getAttribute("name")
      const displayValue = input.value.trim()

      // Видаляємо name, щоб не сабмітилось у неправильному форматі
      input.removeAttribute("name")

      // 👇 Якщо дата вже є (встановлено за замовчуванням), одразу створимо hidden input
      if (displayValue.match(/^\d{2}\.\d{2}\.\d{4}$/)) {
        const hidden = document.createElement("input")
        hidden.type = "hidden"
        hidden.name = originalName
        hidden.value = displayValue.split('.').reverse().join('-') // DD.MM.YYYY → YYYY-MM-DD
        form.appendChild(hidden)
      }

      const picker = new window.Litepicker({
        element: input,
        format: "DD.MM.YYYY",
        lang: "uk",
        dropdowns: {
          minYear: 2024,
          maxYear: new Date().getFullYear() + 1,
          months: true,
          years: true,
        },
        minDate: this.getMinDate(input),
        maxDate: this.getMaxDate(input),
        setup: (picker) => {
          picker.on("selected", (date) => {
            input.value = date.format("DD.MM.YYYY")

            // 🧼 Видалити попередній прихований
            const existing = form.querySelector(`input[type="hidden"][name="${originalName}"]`)
            if (existing) existing.remove()

            // 🆕 Додати прихований input
            const hidden = document.createElement("input")
            hidden.type = "hidden"
            hidden.name = originalName
            hidden.value = date.format("YYYY-MM-DD")
            form.appendChild(hidden)
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

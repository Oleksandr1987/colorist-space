// app/javascript/controllers/client_search_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "item", "group"]

  search() {
    const query = this.inputTarget.value.trim().toLowerCase()

    if (query === "") {
      this.reset()
      return
    }

    const queryDigits = this.normalizePhone(query)
    const isSearchingByPhone = queryDigits.length > 0

    this.groupTargets.forEach((group) => {
      let hasVisibleItems = false

      group
        .querySelectorAll("[data-client-search-target='item']")
        .forEach((item) => {
          const name = item.querySelector(".client-link").textContent.toLowerCase()
          const phoneDigits = this.normalizePhone(item.dataset.phone || "")
          const isVisible = isSearchingByPhone ? phoneDigits.includes(queryDigits) : name.includes(query)

          item.style.display = isVisible ? "" : "none"

          if (isVisible) hasVisibleItems = true
        })

      group.style.display = hasVisibleItems ? "" : "none"
    })
  }

  reset() {
    this.itemTargets.forEach((item) => {
      item.style.display = ""
    })

    this.groupTargets.forEach((group) => {
      group.style.display = ""
    })
  }

  normalizePhone(value) {
    return value.replace(/\D/g, "")
  }
}

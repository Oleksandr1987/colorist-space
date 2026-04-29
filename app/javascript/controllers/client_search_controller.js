// app/javascript/controllers/client_search_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "item", "group"]

  connect() {
    console.log("ClientSearchController connected");
    this.inputTarget.addEventListener("input", () => this.search());
  }

  search() {
    const query = this.inputTarget.value.toLowerCase()

    const normalize = (str) => str.replace(/\D/g, "")

    const queryDigits = normalize(query)
    const isSearchingDigits = queryDigits.length > 0

    this.groupTargets.forEach((group) => {
      let hasVisibleItems = false

      group.querySelectorAll("[data-client-search-target='item']").forEach((item) => {
        const name = item.querySelector(".client-link").textContent.toLowerCase()
        const phones = (item.dataset.phone || "").toLowerCase()

        const phoneDigits = normalize(phones)

        let isVisible

        if (isSearchingDigits) {

          isVisible = phoneDigits.includes(queryDigits)
        } else {

          isVisible = name.includes(query)
        }

        item.style.display = isVisible ? "block" : "none"

        if (isVisible) hasVisibleItems = true
      })

      group.style.display = hasVisibleItems ? "block" : "none"
    })
  }
}

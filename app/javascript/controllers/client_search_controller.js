// app/javascript/controllers/client_search_controller.js
import { Controller } from "@hotwired/stimulus"

const EN_LAYOUT = "qwertyuiop[]asdfghjkl;'zxcvbnm,."
const UK_LAYOUT = "йцукенгшщзхїфівапролджєячсмитьбю"

export default class extends Controller {
  static targets = ["input", "item", "group", "noResults"]

  connect() {
    this.search()
  }

  search() {
    const query = this.normalizeText(this.inputTarget.value)
    const words = query.split(/\s+/).filter(Boolean)

    if (words.length === 0) {
      this.reset()
      return
    }

    const alternativeWords = words.map((word) => this.switchLayout(word))

    let hasResults = false

    this.groupTargets.forEach((group) => {
      let hasVisibleItems = false

      group.querySelectorAll( "[data-client-search-target='item']")
        .forEach((item) => {
          const name = this.normalizeText(item.querySelector(".client-link")?.textContent || "")
          const phoneDigits = this.normalizePhone(item.dataset.phone || "")
          const matchesWord = (word) => {
            if (name.includes(word)) return true

            const digits = this.normalizePhone(word)

            if (digits && phoneDigits.includes(digits)) {
              return true
            }

            return false
          }

          const matches = words.every((word, index) => matchesWord(word) || matchesWord(alternativeWords[index]))

          item.style.display = matches ? "" : "none"

          if (matches) {
            hasVisibleItems = true
            hasResults = true
          }
        })

      group.style.display = hasVisibleItems ? "" : "none"
    })

    if (this.hasNoResultsTarget) {
      this.noResultsTarget.classList.toggle("hidden", hasResults)
    }
  }

  reset() {
    this.itemTargets.forEach((item) => {
      item.style.display = ""
    })

    this.groupTargets.forEach((group) => {
      group.style.display = ""
    })

    if (this.hasNoResultsTarget) {
      this.noResultsTarget.classList.add("hidden")
    }
  }

  normalizeText(value) {
    return value
      .toLocaleLowerCase()
      .normalize("NFC")
      .replace(/['’ʼ`´]/g, "'")
      .replace(/\s+/g, " ")
      .trim()
  }

  normalizePhone(value) {
    return value.replace(/\D/g, "")
  }

  switchLayout(value) {
    return [...value].map((char) => {
      const enIndex = EN_LAYOUT.indexOf(char)

      if (enIndex !== -1) {
        return UK_LAYOUT[enIndex]
      }

      const ukIndex = UK_LAYOUT.indexOf(char)

      if (ukIndex !== -1) {
        return EN_LAYOUT[ukIndex]
      }

      return char
    }).join("")
  }
}

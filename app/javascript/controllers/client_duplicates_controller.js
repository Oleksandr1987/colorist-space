// app/javascript/controllers/client_duplicates_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results", "list", "modal", "modalList", "count"]

  static values = {
    url: String,
    minLength: { type: Number, default: 2 },
    delay: { type: Number, default: 300 }
  }

  connect() {
    this.timer = null
    this.abortController = null
    this.clients = []
    this.totalCount = 0
  }

  disconnect() {
    clearTimeout(this.timer)
    this.abortController?.abort()
  }

  search() {
    clearTimeout(this.timer)
    this.abortController?.abort()

    const term = this.inputTarget.value.trim()

    if (term.length < this.minLengthValue) {
      this.hideResults()
      return
    }

    this.timer = setTimeout(() => this.fetchClients(term), this.delayValue)
  }

  async fetchClients(term) {
    this.abortController = new AbortController()

    try {
      const url = new URL(this.urlValue, window.location.origin)
      url.searchParams.set("term", term)

      const response = await fetch(url, {
        headers: { Accept: "application/json" },
        signal: this.abortController.signal
      })

      if (!response.ok) throw new Error(`HTTP ${response.status}`)

      const data = await response.json()

      if (this.inputTarget.value.trim() !== term) return

      this.clients = data.clients
      this.totalCount = data.total_count

      this.renderResults()
    } catch (error) {
      if (error.name !== "AbortError") {
        console.error("Client duplicates search failed:", error)
        this.hideResults()
      }
    }
  }

  renderResults() {
    if (this.clients.length === 0) {
      this.hideResults()
      return
    }

    this.listTarget.replaceChildren()

    this.clients.slice(0, 3).forEach((client) => {
      this.listTarget.appendChild(this.createClientItem(client))
    })

    this.countTarget.textContent = this.totalCount

    this.resultsTarget.classList.remove("hidden")

    const showAllButton = this.resultsTarget.querySelector("[data-show-all]")
    showAllButton?.classList.toggle("hidden", this.totalCount <= 3)
  }

  createClientItem(client) {
    const link = document.createElement("a")
    link.href = client.url
    link.className = "client-duplicate-item"
    link.dataset.unsavedChangesIgnore = "true"

    const info = document.createElement("div")
    info.className = "client-duplicate-info"

    const name = document.createElement("strong")
    name.textContent = client.name

    const phone = document.createElement("span")
    phone.textContent = client.phone || ""

    info.append(name, phone)
    link.appendChild(info)

    return link
  }

  showAll() {
    this.modalListTarget.replaceChildren()

    this.clients.forEach((client) => {
      this.modalListTarget.appendChild(this.createClientItem(client))
    })

    this.modalTarget.classList.remove("hidden")
  }

  closeModal() {
    this.modalTarget.classList.add("hidden")
  }

  hideResults() {
    this.clients = []
    this.totalCount = 0
    this.resultsTarget.classList.add("hidden")
    this.closeModal()
  }
}

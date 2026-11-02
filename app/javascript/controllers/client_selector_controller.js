
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "name", "clientId", "phone", "suggestions", "suggestion", "clearButton", "search", "row", "empty"]

  connect() {
    this.selectedName = this.nameTarget.value.trim()
    this.hideSuggestions()

    this.onOutsideClick = this.handleOutsideClick.bind(this)
    document.addEventListener("pointerdown", this.onOutsideClick)
  }

  disconnect() {
    document.removeEventListener("pointerdown", this.onOutsideClick)
  }

  input() {
    const name = this.nameTarget.value.trim()

    if (this.clientIdTarget.value && name !== this.selectedName) {
      this.clientIdTarget.value = ""
      this.clientIdTarget.dispatchEvent(new Event("change", { bubbles: true }))

      this.setPhone("")
    }

    this.selectedName = name
    this.toggleClearButton()
    this.showSuggestions()
  }

  focus() {
    this.showSuggestions()
  }

  showSuggestions() {
    const query = this.normalize(this.nameTarget.value)

    if (!query) {
      this.hideSuggestions()
      return
    }

    let matches = 0

    this.suggestionTargets.forEach(row => {
      const name = this.normalize(row.dataset.name)
      const visible = name.includes(query)
      row.classList.toggle("hidden", !visible)

      if (visible) matches++
    })

    this.suggestionsTarget.classList.toggle("hidden", matches === 0)
  }

  hideSuggestions() {
    this.suggestionsTarget.classList.add("hidden")
  }

  selectSuggestion(event) {
    const row = event.currentTarget
    this.selectClient(row)
  }

  selectModalClient(event) {
    const row = event.currentTarget
    this.selectClient(row)
    this.close()
  }

  selectClient(row) {
    this.applyClient({id: row.dataset.clientId, name: row.dataset.name, phone: row.dataset.phone})
    this.hideSuggestions()
  }

  applyClient({ id, name, phone }) {
    const oldId = this.clientIdTarget.value
    const oldName = this.nameTarget.value

    this.clientIdTarget.value = id
    this.nameTarget.value = name
    this.selectedName = name

    if (oldId !== id) {
      this.clientIdTarget.dispatchEvent(new Event("change", { bubbles: true }))
    }

    if (oldName !== name) {
      this.nameTarget.dispatchEvent(new Event("input", { bubbles: true }))
    }

    this.setPhone(phone)
    this.toggleClearButton()
  }

  setPhone(phone) {
    const oldPhone = this.phoneTarget.value

    this.phoneTarget.value = phone
    this.phoneTarget.dispatchEvent(new CustomEvent("phone-mask:change"))

    if (oldPhone !== this.phoneTarget.value) {
      this.phoneTarget.dispatchEvent(new Event("input", { bubbles: true }))
    }
  }

  clear() {
    this.applyClient({id: "", name: "", phone: ""})
    this.hideSuggestions()
    this.nameTarget.focus()
  }

  toggleClearButton() {
    this.clearButtonTarget.classList.toggle("hidden", this.nameTarget.value.trim() === "")
  }

  open() {
    this.hideSuggestions()

    this.searchTarget.value = ""
    this.filterModal()

    this.modalTarget.classList.remove("hidden")
    this.modalTarget.setAttribute("aria-hidden", "false")

    document.activeElement?.blur()
    this.searchTarget.focus({ preventScroll: true })
  }

  close() {
    this.modalTarget.classList.add("hidden")
    this.modalTarget.setAttribute("aria-hidden", "true")
    this.searchTarget.blur()
  }

  filterModal() {
    const query = this.normalize(this.searchTarget.value)
    const digits = this.onlyDigits(query)
    let matches = 0

    this.rowTargets.forEach(row => {
      const name = this.normalize(row.dataset.name)
      const phones = String(row.dataset.searchPhones || "").split(/\s+/).map(phone => this.onlyDigits(phone))
      const visible = !query || name.includes(query) || (digits.length > 0 && phones.some(phone => phone.includes(digits)))

      row.classList.toggle("hidden", !visible)
      if (visible) matches++
    })

    this.emptyTarget.classList.toggle("hidden", matches > 0)
  }

  handleOutsideClick(event) {
    if (!event.target.closest(".client-input-wrapper")) {
      this.hideSuggestions()
    }
  }

  normalize(value) {
    return String(value || "").trim().toLocaleLowerCase()
  }

  onlyDigits(value) {
    return String(value || "").replace(/\D/g, "")
  }
}

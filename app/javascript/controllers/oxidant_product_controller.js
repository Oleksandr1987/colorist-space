import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["value", "name", "type"]

  connect() {
    this.selectedType =
      this.typeTargets.find(button => button.classList.contains("active"))?.dataset.value || "%"

    this.update()
  }

  selectType(event) {
    this.selectedType = event.currentTarget.dataset.value

    this.typeTargets.forEach(button => {
      button.classList.toggle("active", button.dataset.value === this.selectedType)
    })

    this.update()
  }

  update() {
    let value = this.valueTarget.value.trim().replace(",", ".").replace(/[^0-9.]/g, "")

    const parts = value.split(".")
    if (parts.length > 2) {
      value = `${parts.shift()}.${parts.join("")}`
    }

    this.valueTarget.value = value

    if (!value) {
      this.nameTarget.value = ""
      return
    }

    this.nameTarget.value = this.selectedType === "%" ? `${value}%` : `${value} vol`
  }
}

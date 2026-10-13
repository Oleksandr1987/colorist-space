// app/javascript/controllers/phones_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "template"]

  add() {
    const content = this.templateTarget.innerHTML.replaceAll("NEW_RECORD", new Date().getTime())

    this.containerTarget.insertAdjacentHTML("beforeend", content)
    this.element.dispatchEvent(new Event("change", { bubbles: true }))
  }

  remove(event) {
    const row = event.currentTarget.closest(".phone-row")
    if (!row) return

    const idInput = row.querySelector('input[name$="[id]"]')
    const destroyInput = row.querySelector('input[name$="[_destroy]"]')

    if (idInput && destroyInput) {
      destroyInput.value = "1"
      row.hidden = true
    } else {
      row.remove()
    }

    this.element.dispatchEvent(new Event("change", { bubbles: true }))
  }
}

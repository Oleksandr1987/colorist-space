// app/javascript/controllers/phones_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "template"]

  add() {
    const content = this.templateTarget.innerHTML.replaceAll(
      "NEW_RECORD",
      new Date().getTime()
    )

    this.containerTarget.insertAdjacentHTML("beforeend", content)
  }

  remove(event) {
    const row = event.currentTarget.closest(".phone-row")

    const destroyInput = row.querySelector("input[name*='[_destroy]']")

    if (destroyInput) {
      destroyInput.value = "1"
      row.style.display = "none"
    } else {
      row.remove()
    }
  }
}

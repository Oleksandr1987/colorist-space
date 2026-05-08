// controllers/care_products_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["list"]

  add() {
    const id = Date.now()

    const html = `
      <div data-care-products-item data-id="${id}">
        <input placeholder="Name">
        <input type="number" placeholder="Price">
        <input type="number" placeholder="Qty" value="1">

        <button type="button" data-action="click->care-products#remove">×</button>
      </div>
    `

    this.listTarget.insertAdjacentHTML("beforeend", html)
  }

  remove(e) {
    e.currentTarget.closest("[data-care-products-item]").remove()
  }
}

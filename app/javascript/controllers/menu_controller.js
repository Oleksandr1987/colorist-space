import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  connect() {
    console.log("MenuController connected");
  }

  toggle() {
    this.menuTarget.classList.toggle("show");
  }
}

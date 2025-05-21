import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  toggle() {
    this.menuTarget.classList.toggle("hidden")
  }


  connect() {
    console.log("✅ dropdown controller connected")
  }

  toggle() {
    console.log("🔄 toggle called")
    this.menuTarget.classList.toggle("hidden")
  }
}

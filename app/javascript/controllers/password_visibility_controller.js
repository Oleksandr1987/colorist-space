import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "eye", "eyeOff"]

  toggle() {
    const showPassword = this.inputTarget.type === "password"

    this.inputTarget.type = showPassword ? "text" : "password"

    this.eyeOffTarget.classList.toggle("hidden", showPassword)
    this.eyeTarget.classList.toggle("hidden", !showPassword)
  }
}

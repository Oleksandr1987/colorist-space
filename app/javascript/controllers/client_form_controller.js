import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "firstName",
    "lastName",
    "phone",
    "submittedFirstName",
    "submittedLastName",
    "submittedPhone"
  ]

  connect() {
    this.sync()
  }

  sync() {
    this.submittedFirstNameTarget.value = this.firstNameTarget.value
    this.submittedLastNameTarget.value = this.lastNameTarget.value
    this.submittedPhoneTarget.value = this.phoneTarget.value
  }
}

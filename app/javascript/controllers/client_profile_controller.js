// app/javascript/controllers/client_profile_controller.js
import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="client-profile"
export default class extends Controller {
  static targets = ["tab", "tabContent", "menu"]
  static values = { id: Number }

  connect() {
    const savedTab = localStorage.getItem("client-tab") || "styles"

    this.showTabByName(savedTab)
  }

  showTab(event) {
    const tabName = event.currentTarget.dataset.tabName
    this.showTabByName(tabName)
  }

  showTabByName(tabName) {
    localStorage.setItem("client-tab", tabName)

    this.tabContentTargets.forEach((el) =>
      el.classList.toggle("active", el.id === `${tabName}-tab`)
    )

    this.tabTargets.forEach((el) =>
      el.classList.toggle("active", el.dataset.tabName === tabName)
    )
  }

  toggleMenu() {
    this.menuTarget.classList.toggle("hidden")
  }

  copyPhone(event) {
    const phone = event.currentTarget.dataset.phone

    navigator.clipboard.writeText(phone)

    event.currentTarget.classList.add("copied")

    setTimeout(() => {
      event.currentTarget.classList.remove("copied")
    }, 1000)
  }
}

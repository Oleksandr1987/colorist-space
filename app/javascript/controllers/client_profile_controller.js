// app/javascript/controllers/client_profile_controller.js
import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="client-profile"
export default class extends Controller {
  static targets = ["tab", "tabContent", "menu"]
  static values = { id: Number }

  connect() {
    this.showTabByName("styles") // Default tab on page load
  }

  showTab(event) {
    const tabName = event.currentTarget.dataset.tabName
    this.showTabByName(tabName)
  }

  showTabByName(tabName) {
    // Tabs content (sections)
    this.tabContentTargets.forEach((el) =>
      el.classList.toggle("active", el.id === `${tabName}-tab`)
    )

    // Tab buttons (highlight active)
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

  makePrimary(event) {
    const phone = event.currentTarget.dataset.phone

    fetch(`/clients/${this.idValue}/make_primary`, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content
      },
      body: JSON.stringify({ phone: phone })
    }).then(() => {
      window.location.reload()
    })
  }
}

import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="client-profile"
export default class extends Controller {
  static targets = ["tab", "tabContent", "menu", "info"]

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

  toggleInfo() {
    this.infoTarget.classList.toggle("hidden")
  }
}

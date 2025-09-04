import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "button"]

  connect() {
    this.handleOutsideClick = this.handleOutsideClick.bind(this)
    document.addEventListener("click", this.handleOutsideClick)
  }

  disconnect() {
    document.removeEventListener("click", this.handleOutsideClick)
  }

  toggle(event) {
    event.stopPropagation()
    this.closeAllPopovers()

    if (this.menuTarget.classList.contains("hidden")) {
      this.menuTarget.classList.remove("hidden")
    } else {
      this.menuTarget.classList.add("hidden")
    }
  }

  closeAllPopovers() {
    document.querySelectorAll(".popover-menu").forEach(menu => {
      menu.classList.add("hidden")
    })
  }

  handleOutsideClick(event) {
    if (!this.element.contains(event.target)) {
      this.menuTarget.classList.add("hidden")
    }
  }

  // toggle(event) {
  //   event.stopPropagation()
  //   this.closeAllPopovers()
  
  //   if (this.menuTarget.classList.contains("show")) {
  //     this.menuTarget.classList.remove("show")
  //   } else {
  //     this.menuTarget.classList.add("show")
  //   }
  // }
  
  // closeAllPopovers() {
  //   document.querySelectorAll(".popover-menu").forEach(menu => {
  //     menu.classList.remove("show")
  //   })
  // }
  
  // handleOutsideClick(event) {
  //   if (!this.element.contains(event.target)) {
  //     this.menuTarget.classList.remove("show")
  //   }
  // }
}

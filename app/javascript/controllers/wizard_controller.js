// app/javascript/controllers/wizard_controller.js
import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = [
    "container",
    "title",
    "step",
    "nextButton",
    "nextLabel",
    "nextIcon",
    "saveIcon",
    "prevButton",
    "unsavedModal",
    "unsavedTitle",
    "unsavedMessage"
  ]

  static values = {
    initialStep: String,
    servicesTitle: String,
    haircutTitle: String,
    formulaTitle: String,
    careProductsTitle: String,
    photosTitle: String,
    notesTitle: String,
    nextLabel: String,
    saveLabel: String,
    unsavedTitle: String,
    unsavedMessage: String,
    discardLabel: String,
    cancelLabel: String
  }

  connect() {
    console.log("Wizard controller connected")

    const steps = {
      services: 0,
      haircut: 1,
      formula: 2,
      care_products: 3,
      photos: 4,
      notes: 5
    }

    this.current = steps[this.initialStepValue] ?? 0
    this.steps = this.stepTargets
    this.nav = this.element.querySelectorAll(".wiz-item")

    this.isDirty = false
    this.pendingNavigationUrl = null

    this.markDirty = this.markDirty.bind(this)
    this.handleBottomNavigation = this.handleBottomNavigation.bind(this)

    this.element.addEventListener("input", this.markDirty)
    this.element.addEventListener("change", this.markDirty)

    window.addEventListener("formula:changed", this.markDirty)
    window.addEventListener("services:changed", this.markDirty)
    window.addEventListener("wizard:changed", this.markDirty)

    document.addEventListener("click", this.handleBottomNavigation)

    this.element.querySelector("form")?.addEventListener("submit", () => {
      this.isDirty = false
    })

    this.update()
    this.updateNextButton()
    this.updateButtons()
    this.initSwipe()
  }

  disconnect() {
    this.element.removeEventListener("input", this.markDirty)
    this.element.removeEventListener("change", this.markDirty)

    window.removeEventListener("formula:changed", this.markDirty)
    window.removeEventListener("services:changed", this.markDirty)
    window.removeEventListener("wizard:changed", this.markDirty)

    document.removeEventListener("click", this.handleBottomNavigation)
  }

  // ---------------- NAV CLICK ----------------

  go(event) {
    this.current = parseInt(event.currentTarget.dataset.step)

    this.update()
    this.updateNextButton()
    this.updateButtons()
  }

  // ---------------- NEXT ----------------

  next() {
    if (this.current < this.steps.length - 1) {
      this.current++

      this.update()
      this.updateNextButton()
      this.updateButtons()
    }
  }

  // ---------------- PREV ----------------

  prev() {
    if (this.current > 0) {
      this.current--

      this.update()
      this.updateNextButton()
      this.updateButtons()
    }
  }

  // ---------------- UPDATE UI ----------------

  update() {
    this.steps.forEach((el, i) => {
      el.classList.toggle("active", i === this.current)
    })

    this.nav.forEach((el, i) => {
      el.classList.toggle("active", i === this.current)
    })

    const titles = [
      this.servicesTitleValue,
      this.haircutTitleValue,
      this.formulaTitleValue,
      this.careProductsTitleValue,
      this.photosTitleValue,
      this.notesTitleValue
    ]

    this.titleTarget.textContent = titles[this.current]
  }

  // ---------------- SWIPE ----------------

  initSwipe() {
    let startX = 0

    this.containerTarget.addEventListener("touchstart", event => {
      startX = event.changedTouches[0].screenX
    })

    this.containerTarget.addEventListener("touchend", event => {
      const diff = event.changedTouches[0].screenX - startX

      if (Math.abs(diff) > 50) {
        diff > 0 ? this.prev() : this.next()
      }
    })
  }

  // ---------------- NEXT BUTTON ----------------

  updateNextButton() {
    const isLast = this.current === this.steps.length - 1

    if (isLast) {
      this.nextLabelTarget.textContent = this.saveLabelValue.toUpperCase()
      this.nextButtonTarget.type = "submit"

      this.nextIconTarget.style.display = "none"
      this.saveIconTarget.style.display = "inline-block"
    } else {
      this.nextLabelTarget.textContent = this.nextLabelValue
      this.nextButtonTarget.type = "button"

      this.nextIconTarget.style.display = "inline-block"
      this.saveIconTarget.style.display = "none"
    }
  }

  // ---------------- BACK BUTTON ----------------

  updateButtons() {
    if (!this.hasPrevButtonTarget) return

    if (this.current === 0) {
      this.prevButtonTarget.style.visibility = "hidden"
    } else {
      this.prevButtonTarget.style.visibility = "visible"
    }
  }

  // ---------------- CLOSE WIZARD ----------------

  close() {
    if (!this.isDirty) {
      history.back()
      return
    }

    this.pendingNavigationUrl = null
    this.openUnsavedModal()
  }

  // ---------------- BOTTOM NAVIGATION ----------------

  handleBottomNavigation(event) {
    const link = event.target.closest(".bottom-nav .nav-item")

    if (!link) return
    if (!this.isDirty) return

    event.preventDefault()

    this.pendingNavigationUrl = link.href
    this.openUnsavedModal()
  }

  // ---------------- UNSAVED MODAL ----------------

  openUnsavedModal() {
    if (this.hasUnsavedTitleTarget) {
      this.unsavedTitleTarget.textContent = this.unsavedTitleValue
    }

    if (this.hasUnsavedMessageTarget) {
      this.unsavedMessageTarget.textContent = this.unsavedMessageValue
    }

    this.unsavedModalTarget.classList.remove("hidden")
  }

  cancelClose() {
    this.pendingNavigationUrl = null
    this.unsavedModalTarget.classList.add("hidden")
  }

  discardChanges() {
    this.isDirty = false

    if (this.pendingNavigationUrl) {
      window.location.href = this.pendingNavigationUrl
      return
    }

    history.back()
  }

  saveAndClose() {
    const form = this.element.querySelector("form")

    if (!form) return

    this.isDirty = false
    this.unsavedModalTarget.classList.add("hidden")

    form.requestSubmit()
  }

  submitEnd(event) {
    if (!event.detail.success) {
      this.isDirty = true
      return
    }

    if (!this.pendingNavigationUrl) return

    const url = this.pendingNavigationUrl

    this.pendingNavigationUrl = null

    Turbo.visit(url)
  }

  // ---------------- DIRTY ----------------

  markDirty() {
    this.isDirty = true
  }
}

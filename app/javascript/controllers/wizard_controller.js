// app/javascript/controllers/wizard_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "container",
    "title",
    "step",
    "nextButton",
    "nextLabel",
    "nextIcon",
    "saveIcon",
    "prevButton"
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
    saveLabel: String
  }

  connect() {
    const steps = {
      services: 0,
      haircut: 1,
      formula: 2,
      care_products: 3,
      photos: 4,
      notes: 5
    }

    this.steps = this.stepTargets
    this.nav = this.element.querySelectorAll(".wiz-item")

    const initialStep = this.initialStepValue
    const numericStep = Number(initialStep)

    if (Object.hasOwn(steps, initialStep)) {
      this.current = steps[initialStep]
    } else if (
      initialStep !== "" &&
      Number.isInteger(numericStep) &&
      numericStep >= 0 &&
      numericStep < this.steps.length
    ) {
      this.current = numericStep
    } else {
      this.current = 0
    }

    this.onTouchStart = this.handleTouchStart.bind(this)
    this.onTouchEnd = this.handleTouchEnd.bind(this)

    this.containerTarget.addEventListener("touchstart", this.onTouchStart, { passive: true })
    this.containerTarget.addEventListener("touchend", this.onTouchEnd, { passive: true })

    this.update()
    this.updateNextButton()
    this.updateButtons()
  }

  disconnect() {
    this.containerTarget.removeEventListener("touchstart", this.onTouchStart)
    this.containerTarget.removeEventListener("touchend", this.onTouchEnd)
  }

  go(event) {
    const step = Number.parseInt(event.currentTarget.dataset.step, 10)
    if (!Number.isInteger(step) || step < 0 || step >= this.steps.length) return

    this.current = step
    this.refresh()
  }

  next() {
    if (this.current >= this.steps.length - 1) return

    this.current++
    this.refresh()
  }

  prev() {
    if (this.current <= 0) return

    this.current--
    this.refresh()
  }

  refresh() {
    this.update()
    this.updateNextButton()
    this.updateButtons()
    this.updateStepUrl()
  }

  update() {
    this.steps.forEach((element, index) => {
      element.classList.toggle("active", index === this.current)
    })

    this.nav.forEach((element, index) => {
      element.classList.toggle("active", index === this.current)
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

  updateNextButton() {
    const isLast = this.current === this.steps.length - 1

    this.nextLabelTarget.textContent = isLast ? this.saveLabelValue.toUpperCase() : this.nextLabelValue
    this.nextButtonTarget.type = isLast ? "submit" : "button"

    this.nextIconTarget.style.display = isLast ? "none" : "inline-block"
    this.saveIconTarget.style.display = isLast ? "inline-block" : "none"
  }

  updateButtons() {
    if (!this.hasPrevButtonTarget) return

    this.prevButtonTarget.style.visibility = this.current === 0 ? "hidden" : "visible"
  }

  updateStepUrl() {
    const url = new URL(window.location.href)

    url.searchParams.set("step", this.current)

    window.history.replaceState(window.history.state, "", url)
  }

  handleTouchStart(event) {
    this.startX = event.changedTouches[0].screenX
  }

  handleTouchEnd(event) {
    if (this.startX === undefined) return

    const diff = event.changedTouches[0].screenX - this.startX
    this.startX = undefined

    if (Math.abs(diff) <= 50) return

    diff > 0 ? this.prev() : this.next()
  }
}

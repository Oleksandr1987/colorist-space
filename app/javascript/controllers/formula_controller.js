// app/javascript/controllers/formula_controller.js
import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static targets = ["container", "template", "steps", "colorsList", "addStep"]

  static values = {
    sections: Object
  }

  connect() {
    this.initSortable()
    this.initSwipe()
    this.handleAmountInput = this.handleAmountInput.bind(this)
    this.element.addEventListener("input", this.handleAmountInput)
    this.updateStepNumbers()
    this.showAddStepHandler = () => this.showAddStep()
    window.addEventListener("formula:firstStepFilled", this.showAddStepHandler)
  }

  disconnect() {
    this.element.removeEventListener("input", this.handleAmountInput)
    window.removeEventListener("formula:firstStepFilled", this.showAddStepHandler)
    window.removeEventListener("service-note:saved", this.savedHandler)
  }

  // ---------------- COLOR SUM ----------------
  getTotalColorAmount() {
    const inputs = this.element.querySelectorAll("[name*='[amount]']")

    let total = 0
    inputs.forEach(input => {
      const val = parseFloat(input.value)
      if (!isNaN(val)) total += val
    })

    return total
  }

  dispatchColorAmount(step) {
    if (!step) return

    let total = 0

    step
      .querySelectorAll(".ingredient-fields")
      .forEach(wrapper => {
        const destroyInput = wrapper.querySelector("[data-field='destroy']")
        if (destroyInput?.value === "1") return

        const amountInput = wrapper.querySelector("[data-field='amount']")
        if (!amountInput) return

        const amount = parseFloat(amountInput.value || 0)
        if (!Number.isNaN(amount)) {
          total += amount
        }
      })

    window.dispatchEvent(new CustomEvent("formula:colorAmountChanged", { detail: { total, stepId: step.dataset.stepId } }))
  }

  handleAmountInput(event) {
    if (
      !event.target.matches(".ingredient-fields [data-field='amount']")
    ) {
      return
    }

    const step = event.target.closest(".formula-card")
    if (!step) return

    this.dispatchColorAmount(step)
  }

  // ---------------- CREATE STEP ----------------
  createStep(event) {
    event.preventDefault()

    const section = event.currentTarget.dataset.section
    const sectionLabel = this.sectionsValue[section] || section
    const template = this.templateTarget.innerHTML
    const stepId = Date.now()

    let html = template
      .replaceAll("__SECTION_VALUE__", section)
      .replaceAll("__SECTION_LABEL__", sectionLabel)
      .replaceAll("NEW_RECORD", stepId)
    this.containerTarget.insertAdjacentHTML("beforeend", html)

    const newStep = this.containerTarget.lastElementChild
    const destroyInput = newStep.querySelector(".destroy-field")
    if (destroyInput) destroyInput.value = "0"

    const empty = this.element.querySelector(".empty-step")
    if (empty) empty.remove()

    this.containerTarget.classList.remove("hidden")

    if (this.hasAddStepTarget) {
      this.addStepTarget.classList.remove("hidden")
    }

    this.updateStepNumbers()
    this.containerTarget.classList.remove("hidden")
  }

  updateStepNumbers() {
    const steps = Array.from(
      this.containerTarget.querySelectorAll(".formula-step-wrapper")
    ).filter(wrapper => {
      const card = wrapper.querySelector(".formula-card")
      const destroyInput = card?.querySelector(".destroy-field")

      return (
        wrapper.style.display !== "none" && (!destroyInput || destroyInput.value !== "1")
      )
    })

    steps.forEach((step, index) => {
      const el = step.querySelector(".step-number")
      if (el) el.textContent = index + 1
    })
  }

  removeStep(event) {
    event.preventDefault()

    const wrapper = event.currentTarget.closest(".formula-step-wrapper")
    const card = wrapper.querySelector(".formula-card")
    wrapper.style.display = "none"

    const destroyInput = card.querySelector(".destroy-field")
    if (destroyInput) {
      destroyInput.value = "1"
      card.style.display = "none"
    } else {
      card.remove()
    }

    this.updateStepNumbers()

    const step = card
    this.dispatchColorAmount(step)

    const visibleSteps = this.containerTarget.querySelectorAll(".formula-card:not([style*='display: none'])")
    if (visibleSteps.length === 0) {
      if (this.hasAddStepTarget) {
        this.addStepTarget.classList.remove("hidden")
      }

      const empty = this.element.querySelector(".empty-step")
      if (empty) {
        empty.classList.remove("hidden")
      }
    }
  }

  openColorModal(event) {
    event.preventDefault()

    const step = event.currentTarget.closest(".formula-card")
    window.dispatchEvent(new CustomEvent("color:open", {
      detail: { step }
    }))
  }

  // ---------------- COLORS ----------------
   addColor(event) {
    event.preventDefault()

    const card = event.currentTarget.closest(".formula-card")
    const list = card.querySelector("[data-formula-target='colorsList']")
    const prototype = list.dataset.prototype
    const stepIndex = card.dataset.stepId
    const newId = `${Date.now()}_${Math.random().toString(36).slice(2)}`

    let html = prototype.replace(/NEW_COLOR/g, newId).replace(/NEW_RECORD/g, stepIndex)
    list.insertAdjacentHTML("beforeend", html)

    this.dispatchColorAmount(card)
   }

  removeColor(event) {
    event.preventDefault()
    event.stopPropagation()

    const displayRow = event.currentTarget.closest(".color-row-display")
    if (!displayRow) return

    const ingredientId = displayRow.dataset.id
    const step = displayRow.closest(".formula-card")
    if (!ingredientId || !step) return

    const hidden = step.querySelector(`.ingredient-fields[data-id="${CSS.escape(ingredientId)}"]`)
    if (hidden) {
      const destroyInput = hidden.querySelector("[data-field='destroy']")
      const persisted = !ingredientId.startsWith("new_")

      if (persisted && destroyInput) {
        destroyInput.value = "1"
        hidden.classList.add("hidden")
      } else {
        hidden.remove()
      }
    }

    displayRow.remove()

    this.dispatchColorAmount(step)
    window.dispatchEvent(new CustomEvent("formula:changed"))
  }

  editColor(event) {
    event.preventDefault()
    event.stopPropagation()

    const display = event.currentTarget.closest(".color-row-display")
    if (!display) return

    const ingredientId = display.dataset.id
    if (!ingredientId) return

    const step = display.closest(".formula-card")
    if (!step) return

    window.dispatchEvent(new CustomEvent("color:open", { detail: {step, ingredientId } }))
  }

  // ---------------- DRAG ----------------
  initSortable() {
    if (!this.hasStepsTarget) return

    Sortable.create(this.stepsTarget, {
      animation: 150,
      ghostClass: "drag-ghost",
      handle: ".step-header",
      onEnd: () => this.updateStepNumbers()
    })
  }

  // ---------------- SWIPE ----------------
  initSwipe() {
    if (!this.hasStepsTarget) return

    let startX = 0
    this.stepsTarget.addEventListener("touchstart", e => {
      startX = e.changedTouches[0].screenX
    })

    this.stepsTarget.addEventListener("touchend", e => {
      const diff = e.changedTouches[0].screenX - startX
      if (Math.abs(diff) > 60) {
        diff > 0 ? this.prevStep() : this.nextStep()
      }
    })
  }

  nextStep() {
    const steps = this.stepsTarget.children
    const active = this.getActiveIndex(steps)

    if (active < steps.length - 1) {
      steps[active].classList.remove("active")
      steps[active + 1].classList.add("active")
    }
  }

  prevStep() {
    const steps = this.stepsTarget.children
    const active = this.getActiveIndex(steps)

    if (active > 0) {
      steps[active].classList.remove("active")
      steps[active - 1].classList.add("active")
    }
  }

  getActiveIndex(steps) {
    return Array.from(steps).findIndex(el =>
      el.classList.contains("active")
    )
  }

  showAddStep() {
    if (this.hasAddStepTarget) {
      this.addStepTarget.classList.remove("hidden")
    }
  }
}

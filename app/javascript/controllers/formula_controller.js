// app/javascript/controllers/formula_controller.js
import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"
import { Turbo } from "@hotwired/turbo-rails"
export default class extends Controller {
  static targets = ["container", "template", "steps", "colorsList"]

  connect() {
    this.initSortable()
    this.initSwipe()
    this.observeAmountChanges()
  }

  // ---------------- COLOR SUM ----------------
  getTotalColorAmount() {
    const inputs = this.element.querySelectorAll(
      "[name*='[amount]']"
    )

    let total = 0

    inputs.forEach(input => {
      const val = parseFloat(input.value)
      if (!isNaN(val)) total += val
    })

    return total
  }

  dispatchColorAmount() {
    const total = this.getTotalColorAmount()

    window.dispatchEvent(
      new CustomEvent("formula:colorAmountChanged", {
        detail: { total }
      })
    )
  }

  observeAmountChanges() {
    this.element.addEventListener("input", (e) => {
      if (e.target.name?.includes("[amount]")) {
        this.dispatchColorAmount()
      }
    })
  }

  // ---------------- CREATE STEP ----------------
  createStep(event) {
    event.preventDefault()

    const section = event.currentTarget.dataset.section
    const template = this.templateTarget.innerHTML
    const uid = () => `${Date.now()}_${Math.random().toString(36).slice(2)}`
    const stepId = uid()

    let html = template
      .replace(/__SECTION__/g, section)
      .replace(/NEW_RECORD/g, stepId)
      .replace(/NEW_COLOR/g, uid())

    this.containerTarget.insertAdjacentHTML("beforeend", html)
    // this.application.load(this.containerTarget)
    this.updateStepNumbers()
    this.containerTarget.classList.remove("hidden")
  }

  updateStepNumbers() {
    const steps = this.containerTarget.querySelectorAll(".formula-card")

    steps.forEach((step, index) => {
      const el = step.querySelector(".step-number")
      if (el) el.textContent = index + 1
    })
  }

  removeStep(event) {
    event.preventDefault()

    const card = event.currentTarget.closest(".formula-card")
    const destroyInput = card.querySelector(".destroy-field")

    if (destroyInput) {
      destroyInput.value = "1"
      card.style.display = "none"
    } else {
      card.remove()
    }

    this.updateStepNumbers()
    this.dispatchColorAmount()

    const visibleSteps = this.containerTarget.querySelectorAll(".formula-card:not([style*='display: none'])")

      if (visibleSteps.length === 0) {
        this.containerTarget.classList.add("hidden")
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

    let html = prototype
      .replace(/NEW_COLOR/g, newId)
      .replace(/NEW_RECORD/g, stepIndex)

    list.insertAdjacentHTML("beforeend", html)

    this.dispatchColorAmount()
   }

  // removeColor(event) {
  //   event.preventDefault()

  //   const row = event.currentTarget.closest(".color-row")
  //   const destroyInput = row.querySelector("input[name*='_destroy']")

  //   if (destroyInput) {
  //     destroyInput.value = "1"
  //     row.style.display = "none"
  //   } else {
  //     row.remove()
  //   }

  //   this.dispatchColorAmount()
  // }

  // removeColor(event) {
  //   event.preventDefault()

  //   const btn = event.currentTarget

  //   // 🔥 UI рядок
  //   const displayRow = btn.closest(".color-row-display")
  //   if (displayRow) displayRow.remove()

  //   // 🔥 hidden row (якщо є)
  //   const hiddenRow = btn.closest(".color-row")
  //   if (hiddenRow) {
  //     const destroyInput = hiddenRow.querySelector("input[name*='_destroy']")

  //     if (destroyInput) {
  //       destroyInput.value = "1"
  //       hiddenRow.style.display = "none"
  //     } else {
  //       hiddenRow.remove()
  //     }
  //   }

  //   // 🔥 MAGIC → live update
  //   this.dispatchColorAmount()
  // }
  removeColor(event) {
    event.preventDefault()

    const btn = event.currentTarget
    const displayRow = btn.closest(".color-row-display")

    if (!displayRow) return

    const id = displayRow.dataset.id

    // 🔥 remove UI
    displayRow.remove()

    // 🔥 знайти hidden по id
    const hidden = this.element.querySelector(
      `.ingredient-fields[data-id="${id}"]`
    )

    if (hidden) {
      const destroyInput = hidden.querySelector("input[name*='_destroy']")

      if (destroyInput) {
        destroyInput.value = "1"
        hidden.style.display = "none"
      } else {
        hidden.remove()
      }
    }

    // 🔥 live recalc
    this.dispatchColorAmount()
  }

  // ---------------- DRAG ----------------
  initSortable() {
    if (!this.hasStepsTarget) return

    Sortable.create(this.stepsTarget, {
      animation: 150,
      ghostClass: "drag-ghost",
      handle: ".step-header"
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

  addIngredient(event) {
    event.preventDefault()
    const stepIndex = event.currentTarget.dataset.stepIndex

    // const url = `/service_notes/${this.data.get("id")}/add_ingredient`
    const serviceNoteId = this.element.dataset.serviceNoteId
    const clientId = this.element.dataset.clientId

    const url = `/clients/${clientId}/service_notes/${serviceNoteId}/add_ingredient`

    // 
    fetch(url, {
      method: "POST",
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
        "Accept": "text/vnd.turbo-stream.html",
        "Content-Type": "application/json"
      },
      body: JSON.stringify({ step_index: stepIndex })
    })
    .then(r => r.text())
    .then(html => {
      Turbo.renderStreamMessage(html)
    })
  }
}

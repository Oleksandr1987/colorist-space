// app/javascript/controllers/formula_controller.js
import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static targets = ["container", "template", "steps", "colorsList", "addStep"]

  static values = {
    sections: Object,
    editIcon: String,
    deleteIcon: String
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
  }

  // ---------------- COLOR SUM ----------------
  getTotalColorAmount() {
    const inputs = this.element.querySelectorAll(".ingredient-fields [data-field='amount']")

    let total = 0
    inputs.forEach(input => {
      const wrapper = input.closest(".ingredient-fields")
      if (wrapper.querySelector("[data-field='destroy']")?.value === "1") return
      if ((wrapper.querySelector("[data-field='kind']")?.value || "color") !== "color") return
      if (wrapper.closest(".formula-step-wrapper")?.querySelector(".destroy-field")?.value === "1") return
      const val = parseFloat(input.value)
      if (!isNaN(val)) total += val
    })

    return total
  }

  dispatchColorAmount(step) {
    if (!step) return

    let total = 0
    const stepDeleted = step.querySelector(".destroy-field")?.value === "1"

    step
      .querySelectorAll(".ingredient-fields")
      .forEach(wrapper => {
        if (stepDeleted) return
        const destroyInput = wrapper.querySelector("[data-field='destroy']")
        if (destroyInput?.value === "1") return

        const kindInput = wrapper.querySelector("[data-field='kind']")
        if (kindInput && kindInput.value !== "color") return

        const amountInput = wrapper.querySelector("[data-field='amount']")
        if (!amountInput) return

        const amount = parseFloat(amountInput.value || 0)

        if (Number.isFinite(amount)) {
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
  nextNestedIndex() {
    this.nestedIndexCounter = (this.nestedIndexCounter || 0) + 1

    return String(Date.now() * 1000 + this.nestedIndexCounter)
  }

  createStep(event) {
    event.preventDefault()

    const section = event.currentTarget.dataset.section
    const sectionLabel = this.sectionsValue[section] || section
    const template = this.templateTarget.innerHTML
    const stepId = this.nextNestedIndex()

    const html = template
      .replaceAll("__SECTION_VALUE__", section)
      .replaceAll("__SECTION_LABEL__", sectionLabel)
      .replaceAll("NEW_RECORD", stepId)

    this.containerTarget.insertAdjacentHTML("beforeend", html)

    const newStep = this.containerTarget.lastElementChild
    const destroyInput = newStep.querySelector(".destroy-field")

    if (destroyInput) {
      destroyInput.value = "0"
    }

    this.element.querySelector(".empty-step")?.classList.add("hidden")

    this.containerTarget.classList.remove("hidden")

    if (this.hasAddStepTarget) {
      this.addStepTarget.classList.remove("hidden")
    }

    this.updateStepNumbers()
    window.dispatchEvent(new CustomEvent("formula:changed"))
  }

  updateStepNumbers() {
    const steps = Array.from(this.containerTarget.querySelectorAll(".formula-step-wrapper"))
    .filter(wrapper => {
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
    if (!wrapper) return

    const card = wrapper.querySelector(".formula-card")
    if (!card) return

    const destroyInput = card.querySelector(".destroy-field")

    if (destroyInput) {
      destroyInput.value = "1"
    }

    wrapper.style.display = "none"
    card.style.display = "none"

    this.updateStepNumbers()

    this.dispatchColorAmount(card)

    if (!this.hasActiveFormulaSteps()) {
      const empty = this.element.querySelector(".empty-step")
      if (empty) {
        empty.classList.remove("hidden")
      }
      if (this.hasAddStepTarget) {
        this.addStepTarget.classList.remove("hidden")
      }
    }
    window.dispatchEvent(new CustomEvent("formula:changed"))
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
    const newId = this.nextNestedIndex()

    let html = prototype.replace(/NEW_COLOR/g, newId).replace(/NEW_RECORD/g, stepIndex)
    list.insertAdjacentHTML("beforeend", html)

    this.dispatchColorAmount(card)
    window.dispatchEvent(new CustomEvent("formula:changed"))
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


  // ---------------- ADDITIVES ----------------
  openAdditiveModal(event) {
    event.preventDefault()

    const step = event.currentTarget.closest(".formula-card")
    if (!step) return

    window.dispatchEvent(new CustomEvent("additive:open", { detail: { step } }))
  }

  editAdditive(event) {
    event.preventDefault()
    event.stopPropagation()

    const display = event.currentTarget.closest(".additive-row-display")
    if (!display) return

    const ingredientId = display.dataset.id
    const step = display.closest(".formula-card")

    if (!ingredientId || !step) return

    window.dispatchEvent(new CustomEvent("additive:open", { detail: { step, ingredientId } }))
  }

  removeAdditive(event) {
    event.preventDefault()
    event.stopPropagation()

    const display = event.currentTarget.closest(".additive-row-display")
    if (!display) return

    const ingredientId = display.dataset.id
    const step = display.closest(".formula-card")

    if (!ingredientId || !step) return

    const hidden = [...step.querySelectorAll(".ingredient-fields")].find(element => element.dataset.id === ingredientId)

    if (hidden) {
      const destroyInput = hidden.querySelector("[data-field='destroy']")

      if (ingredientId.startsWith("new_")) {
        hidden.remove()
      } else if (destroyInput) {
        destroyInput.value = "1"
        hidden.classList.add("hidden")
      }
    }

    display.remove()

    this.dispatchColorAmount(step)
    window.dispatchEvent(new CustomEvent("formula:changed"))
  }

  // ---------------- IMPORT FORMULA ----------------
  hasActiveFormulaSteps() {
    return Array.from(
      this.containerTarget.querySelectorAll(".formula-step-wrapper")
    ).some(wrapper => {
      const destroy = wrapper.querySelector(".destroy-field")

      return wrapper.style.display !== "none" && destroy?.value !== "1"
    })
  }


  importSteps(steps) {
    if (!Array.isArray(steps) || steps.length === 0) {
      return false
    }

    if (!this.hasTemplateTarget) {
      return false
    }

    const allowedSections = ["roots", "midshaft", "length", "strands", "all_over"]

    if (steps.some(step => !allowedSections.includes(step.section))) {
      return false
    }

    const fragment = document.createDocumentFragment()

    try {
      steps.forEach((step, index) => {
        const wrapper = this.buildImportedStep(step, index)
        fragment.appendChild(wrapper)
      })
    } catch (error) {
      console.error("Formula import:", error)
      return false
    }

    this.containerTarget.appendChild(fragment)
    this.element.querySelector(".empty-step")?.classList.add("hidden")
    this.containerTarget.classList.remove("hidden")

    if (this.hasAddStepTarget) {
      this.addStepTarget.classList.remove("hidden")
    }

    this.updateStepNumbers()

    requestAnimationFrame(() => {
      this.containerTarget
        .querySelectorAll(".formula-card")
        .forEach(card => {
          const wrapper = card.closest(".formula-step-wrapper")

          if (wrapper?.style.display === "none") return
          if (card.querySelector(".destroy-field")?.value === "1") return

          this.dispatchColorAmount(card)
        })

      window.dispatchEvent(new CustomEvent("formula:changed"))
      window.dispatchEvent(new CustomEvent("formula:firstStepFilled"))
    })

    return true
  }

  buildImportedStep(step, index) {
    const stepId = this.nextNestedIndex()
    const sectionLabel = this.sectionsValue[step.section] || step.section
    const html = this.templateTarget.innerHTML
      .replaceAll("__SECTION_VALUE__", step.section)
      .replaceAll("__SECTION_LABEL__", sectionLabel)
      .replaceAll("NEW_RECORD", stepId)

    const template = document.createElement("template")
    template.innerHTML = html.trim()

    const wrapper = template.content.firstElementChild

    if (!wrapper) {
      throw new Error("Formula step template is empty")
    }

    const card = wrapper.querySelector(".formula-card")

    if (!card) {
      throw new Error("Formula card not found")
    }

    const destroy = card.querySelector(".destroy-field")
    if (destroy) destroy.value = "0"

    const timeInput = card.querySelector(`input[name$="[time]"]`)

    if (timeInput) {
      timeInput.value = step.time ?? 0
    }

    ;(step.ingredients || []).forEach(ingredient => {
      this.importIngredient(card, ingredient, stepId)
    })

    const oxidantInput = card.querySelector('[data-developer-target="input"]')

    if (oxidantInput) {
      const oxidants = Array.isArray(step.oxidant) ? step.oxidant : step.oxidant ? [step.oxidant] : []

      oxidantInput.value = JSON.stringify(oxidants)
    }

    return wrapper
  }

  importIngredient(card, ingredient, stepId) {
    const ingredientTemplate = card.querySelector('[data-formula-target="ingredientTemplate"]')
    const hiddenList = card.querySelector('[data-formula-target="colorsList"]')

    if (!ingredientTemplate || !hiddenList) {
      throw new Error("Ingredient template or container not found")
    }

    const ingredientId = `new_${crypto.randomUUID()}`
    const ingredientIndex = this.nextNestedIndex()
    const html = ingredientTemplate.innerHTML.replaceAll("STEP_ID", stepId).replaceAll("NEW_ID", ingredientIndex)
    const template = document.createElement("template")
    template.innerHTML = html.trim()

    const fields = template.content.querySelector(".ingredient-fields")

    if (!fields) {
      throw new Error("Ingredient fields not found")
    }

    fields.dataset.id = ingredientId
    fields.dataset.unit = ingredient.unit || "g"

    const values = {
      shade: ingredient.shade ?? "",
      brand: ingredient.brand ?? "",
      amount: ingredient.amount ?? "",
      formula_product_id: ingredient.formula_product_id ?? "",
      price: ingredient.price ?? 0,
      kind: ingredient.kind === "additive" ? "additive" : "color",
      destroy: "0"
    }

    Object.entries(values).forEach(([name, value]) => {
      const input = fields.querySelector(`[data-field="${name}"]`)
      if (input) input.value = value
    })

    hiddenList.appendChild(fields)

    this.renderImportedIngredient(card, ingredient, ingredientId)
  }

  renderImportedIngredient(card, ingredient, ingredientId) {
    const additive = ingredient.kind === "additive"

    const list = additive ? card.querySelector("[data-additive-list]") : card.querySelector('[data-color-target="list"]')

    if (!list) {
      throw new Error("Ingredient display list not found")
    }

    const row = document.createElement("div")

    row.className = additive ? "color-row-display additive-row-display" : "color-row-display"

    row.dataset.id = ingredientId

    row.innerHTML = `
      <div class="color-left">
        <span class="shade"></span>
        <span class="brand"></span>
      </div>

      <div class="color-right">
        <span class="amount"></span>

        <div class="color-actions">
          <button type="button"
                  class="edit-btn"
                  data-action="click->formula#${additive ? "editAdditive" : "editColor"}">
            <img class="edit-icon" alt="">
          </button>

          <button type="button"
                  class="delete-btn"
                  data-action="click->formula#${additive ? "removeAdditive" : "removeColor"}">
            <img class="delete-icon" alt="">
          </button>
        </div>
      </div>
    `

    row.querySelector(".shade").textContent = ingredient.shade || ""
    row.querySelector(".brand").textContent = ingredient.brand || ""

    const unit = ingredient.unit || "g"

    row.querySelector(".amount").textContent =
      `${ingredient.amount ?? 0}${unit}`

    row.querySelector(".edit-icon").src = this.editIconValue
    row.querySelector(".delete-icon").src = this.deleteIconValue

    list.appendChild(row)
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

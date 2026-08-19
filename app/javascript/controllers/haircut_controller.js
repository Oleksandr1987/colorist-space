// app/javascript/controllers/haircut_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "template", "addStep", "pickerModal", "pickerTitle", "pickerList"]

	static values = {
		title: String,
		selectZone: String,
    stepLabel: String,
		zones: Object
	}

  connect() {
    this.updateNumbers()
  }

  createStep(event) {
    event.preventDefault()
    event.stopPropagation()

    const button = event.currentTarget
    const zone = button.dataset.zone
    const existingStep = this.findStepByZone(zone)

    if (existingStep) {
      const destroyInput = existingStep.querySelector(".destroy-field")

      if (destroyInput?.value !== "1") {
        this.closeZonePicker()
        this.openStep(existingStep)

        existingStep.scrollIntoView({behavior: "smooth", block: "center"})

        return
      }

      destroyInput.value = "0"
      existingStep.style.display = ""

      this.openStep(existingStep)
      this.closeZonePicker()
      this.updateNumbers()

      window.dispatchEvent(new CustomEvent("wizard:changed"))

      return
    }

    const id = `${Date.now()}_${Math.random().toString(36).slice(2, 8)}`
    const zoneLabel = this.zonesValue[zone] || zone

    const html = this.templateTarget.innerHTML
      .replaceAll("NEW_RECORD", id)
      .replaceAll("__ZONE_VALUE__", zone)
      .replaceAll("__ZONE_LABEL__", zoneLabel)

    this.containerTarget.insertAdjacentHTML("beforeend", html)

    const newStep = this.containerTarget.lastElementChild

    if (!newStep) return

    this.openStep(newStep)

    const empty = this.element.querySelector(".empty-haircut-step")

    empty?.remove()

    if (this.hasAddStepTarget) {
      this.addStepTarget.classList.remove("hidden")
    }

    this.closeZonePicker()
    this.updateNumbers()

    window.dispatchEvent(new CustomEvent("wizard:changed"))
  }

  openStep(step) {
    const content = step.querySelector("[data-collapse-target='content']")

    content?.classList.remove("hidden")
    step.classList.add("open")
  }

  saveStep(event) {
    event.preventDefault()
    event.stopPropagation()

    const wrapper = event.currentTarget.closest(".formula-step-wrapper")

    if (!wrapper) return

    const content = wrapper.querySelector(
      "[data-collapse-target='content']"
    )

    content?.classList.add("hidden")
    wrapper.classList.remove("open")

    window.dispatchEvent(
      new CustomEvent("wizard:changed")
    )
  }

  closeZonePicker() {
    if (!this.hasAddStepTarget) return

    const content = this.addStepTarget.querySelector("[data-collapse-target='content']")

    content?.classList.add("hidden")
    this.addStepTarget.classList.remove("open")
  }

  findStepByZone(zone) {
    return Array.from(
      this.containerTarget.querySelectorAll(".formula-step-wrapper")
    ).find(wrapper => {
      const zoneInput = wrapper.querySelector(
        "input[name*='[zone]']"
      )

      return zoneInput?.value === zone
    })
  }

  removeStep(event) {
    event.preventDefault()
    event.stopPropagation()

    const wrapper = event.currentTarget.closest(".formula-step-wrapper")

    if (!wrapper) return

    const destroyInput = wrapper.querySelector(".destroy-field")

    if (destroyInput) {
      destroyInput.value = "1"
    }

    wrapper.style.display = "none"

    this.updateNumbers()

    const activeSteps = Array.from(
      this.containerTarget.querySelectorAll(
        ".formula-step-wrapper"
      )
    ).filter(step => {
      const destroy = step.querySelector(".destroy-field")

      return destroy?.value !== "1"
    })

    if (activeSteps.length === 0) {
      this.renderEmptyState()
    }

    window.dispatchEvent(new CustomEvent("wizard:changed"))
  }

  updateNumbers() {
    const activeSteps = Array.from(
      this.containerTarget.querySelectorAll(
        ".formula-step-wrapper"
      )
    ).filter(step => {
      const destroyInput = step.querySelector(".destroy-field")

      return destroyInput?.value !== "1"
    })

    activeSteps.forEach((step, index) => {
      const number = step.querySelector(".step-number")

      if (number) {
        number.textContent = index + 1
      }
    })

    this.element.querySelectorAll(
      ".haircut-zones-grid .section-btn"
    ).forEach(button => {
      button.classList.remove("occupied")
      button.removeAttribute("data-step-number")
      button.removeAttribute("data-step-label")
    })

    activeSteps.forEach((step, index) => {
      const zoneInput = step.querySelector(
        "input[name*='[zone]']"
      )

      const zone = zoneInput?.value

      if (!zone) return

      this.element.querySelectorAll(
        ".haircut-zones-grid .section-btn"
      ).forEach(button => {
        if (button.dataset.zone !== zone) return

        button.classList.add("occupied")
        button.dataset.stepNumber = index + 1
        button.dataset.stepLabel = this.stepLabelValue
      })
    })
  }

	selectZone(event) {
		event.preventDefault()

		const btn = event.currentTarget
		const zone = btn.dataset.zone
		const wrapper = btn.closest(".formula-card")

		wrapper.querySelectorAll(".zone-chip")
			.forEach(el => el.classList.remove("active"))

		btn.classList.add("active")

		const input = wrapper.querySelector("input[name*='[zone]']")

		if (input) {
			input.value = zone
		}

		const title = wrapper.querySelector(".haircut-zone-title")

		if (title) {
      title.textContent = this.zonesValue[zone] || zone
    }
	}

	renderEmptyState() {
		if (this.element.querySelector(".empty-haircut-step")) {
			return
		}

		const html = `
			<div class="formula-step-wrapper empty-haircut-step"
					data-controller="collapse">
				<div class="formula-step-header"
						data-action="click->collapse#toggle">
					<span>${this.stepLabelValue} 1</span>

					<svg class="chevron"
							xmlns="http://www.w3.org/2000/svg"
							viewBox="0 0 24 24"
							fill="none"
							stroke="currentColor"
							stroke-width="2">

						<path d="m6 9 6 6 6-6"/>

					</svg>
				</div>

				<div class="formula-step-content"
						data-collapse-target="content">
					<div class="sections-wrapper">
						<h5>${this.selectZoneValue}</h5>
						<div class="haircut-zones-grid">
							${this.zoneButtons()}
						</div>
					</div>
				</div>
			</div>
		`

		this.element.insertAdjacentHTML("beforeend", html)
	}

	zoneButtons() {
    return Object.entries(this.zonesValue).map(([zone, label]) => {
      return `
        <button type="button"
                class="section-btn"
                data-action="click->haircut#createStep"
                data-zone="${zone}">
          ${label}
        </button>
      `
    }).join("")
  }

  clearField(event) {
    event.preventDefault()

    const block = event.currentTarget.closest(".formula-block")
    const valueRow = block.querySelector(".haircut-value-row")
    const select = block.querySelector("select")

    if (select) {
      select.value = ""
      select.classList.remove("hidden")
    }

    valueRow?.remove()
  }

  openPicker(event) {
    this.currentPicker = event.currentTarget
    this.pickerTitleTarget.textContent = this.currentPicker.dataset.title
    this.pickerListTarget.innerHTML = ""

    const values = this.currentPicker.dataset.values.split("|")
    const labels = this.currentPicker.dataset.labels.split("|")
    const currentValue = this.currentPicker.dataset.currentValue

    values.forEach((value, index) => {
      const button = document.createElement("button")

      button.type = "button"
      button.className = "picker-option"

      if (value === currentValue) {
        button.classList.add("active")
      }

      button.dataset.value = value
      button.textContent = labels[index]
      button.addEventListener("click", this.selectPickerValue.bind(this))

      this.pickerListTarget.appendChild(button)
    })
    this.pickerModalTarget.classList.remove("hidden")
  }

  selectPickerValue(event) {
    const value = event.currentTarget.dataset.value
    const label = event.currentTarget.textContent
    const block = this.currentPicker.closest(".formula-block")
    const hidden = block.querySelector(".picker-hidden")

    hidden.value = value

    this.currentPicker.dataset.currentValue = value
    this.currentPicker.querySelector(".picker-value").textContent = label
    this.closePicker()
  }

  closePicker() {
    this.pickerModalTarget.classList.add("hidden")
  }

  stop(event) {
    event.stopPropagation()
  }
}

// app/javascript/controllers/haircut_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "template", "addStep"]

	static values = {
		title: String,
		selectZone: String,
		zones: Object
	}

  connect() {
    this.updateNumbers()
  }

  createStep(event) {
    event.preventDefault()

    const zone = event.currentTarget.dataset.zone

    const existingZones = Array.from(
      this.containerTarget.querySelectorAll(
        "input[name*='[zone]']"
      )
    )
      .map(el => el.value)
      .filter(Boolean)

    if (existingZones.includes(zone)) {
      return
    }

    const id = Date.now()

    let html = this.templateTarget.innerHTML
      .replace(/NEW_RECORD/g, id)
      .replace(/__ZONE__/g, zone)

    this.containerTarget.insertAdjacentHTML(
      "beforeend",
      html
    )

    const newStep = this.containerTarget.lastElementChild

    const content =
      newStep?.querySelector(
        "[data-collapse-target='content']"
      )

    if (content) {
      content.classList.remove("hidden")
    }

    if (newStep) {
      newStep.classList.add("open")
    }

    const empty = this.element.querySelector(
      ".empty-haircut-step"
    )

    if (empty) {
      empty.remove()
    }

    if (this.hasAddStepTarget) {
      this.addStepTarget.classList.remove("hidden")
    }

    this.updateNumbers()
  }

  removeStep(event) {
		event.preventDefault()

		const wrapper = event.currentTarget.closest(
			".formula-step-wrapper"
		)

		wrapper.style.display = "none"

		const destroyInput = wrapper.querySelector(
			".destroy-field"
		)

		if (destroyInput) {
			destroyInput.value = "1"
		}

		this.updateNumbers()

		const visible = this.containerTarget.querySelectorAll(
			".formula-step-wrapper:not([style*='display: none'])"
		)

		if (visible.length === 0) {
			this.renderEmptyState()
		}
	}

  updateNumbers() {
    const steps = Array.from(
      this.containerTarget.querySelectorAll(
        ".formula-step-wrapper"
      )
    ).filter(step => {
      return step.style.display !== "none"
    })

    steps.forEach((step, index) => {
      const number = step.querySelector(".step-number")

      if (number) {
        number.textContent = index + 1
      }
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

		const input = wrapper.querySelector(
			"input[name*='[zone]']"
		)

		if (input) {
			input.value = zone
		}

		const title = wrapper.querySelector(
			".haircut-zone-title"
		)

		if (title) {
			title.textContent = zone.toUpperCase()
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

					<span>STEP 1</span>

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
		return [
			"lower occipital",
			"upper occipital",
			"temporal",
			"fringe",
			"crown",
			"all over"
		].map(zone => {
			return `
				<button type="button"
								class="section-btn"
								data-action="click->haircut#createStep"
								data-zone="${zone}">
					${this.zonesValue[zone]}
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
}

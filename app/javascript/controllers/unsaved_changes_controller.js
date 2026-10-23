// app/javascript/controllers/unsaved_changes_controller.js
import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["form", "modal"]

  static values = {
    streamSave: { type: Boolean, default: false },
    backUrl: String,
    initialDirty: { type: Boolean, default: false }
  }

  connect() {
    this.initialState = this.formState()
    this.isDirty = this.initialDirtyValue
    this.externalDirty = this.initialDirtyValue
    this.isInitializing = true
    this.hasUserChanged = false
    this.isSubmitting = false
    this.isLeaving = false
    this.pendingUrl = null
    this.pendingHistory = false
    this.saveBeforeLeaving = false

    this.onChange = this.handleChange.bind(this)
    this.onNavigation = this.handleNavigation.bind(this)
    this.onBeforeVisit = this.handleBeforeVisit.bind(this)
    this.onBeforeUnload = this.handleBeforeUnload.bind(this)
    this.onSubmitStart = this.submitStart.bind(this)
    this.onSubmitEnd = this.submitEnd.bind(this)
    this.onExternalChange = this.markDirty.bind(this)
    this.onDependencyReady = this.dependencyReady.bind(this)

    this.element.addEventListener("input", this.onChange)
    this.element.addEventListener("change", this.onChange)

    this.externalEvents = ["formula:changed", "services:changed", "wizard:changed"]

    if (this.element.classList.contains("wizard-screen")) {
      this.externalEvents.forEach(name => {window.addEventListener(name, this.onExternalChange)})
    }

    this.element.addEventListener("unsaved-changes:changed", this.onExternalChange)
    this.element.addEventListener("unsaved-changes:ready", this.onDependencyReady)

    document.addEventListener("click", this.onNavigation)
    document.addEventListener("turbo:before-visit", this.onBeforeVisit)
    window.addEventListener("beforeunload", this.onBeforeUnload)

    this.formTarget.addEventListener("turbo:submit-start", this.onSubmitStart)
    this.formTarget.addEventListener("turbo:submit-end", this.onSubmitEnd)

    this.dependencies = [
      {identifier: "phone-mask", readyAttribute: "data-unsaved-ready-phone-mask"},
      {identifier: "service-selector", readyAttribute: "data-unsaved-ready-service-selector"},
      {identifier: "datepicker", readyAttribute: "data-unsaved-ready-datepicker"}
    ]

    this.finishInitialization()
  }

  disconnect() {
    this.element.removeEventListener("input", this.onChange)
    this.element.removeEventListener("change", this.onChange)

    if (this.element.classList.contains("wizard-screen")) {
      this.externalEvents.forEach(name => {window.removeEventListener(name, this.onExternalChange)})
    }

    this.element.removeEventListener("unsaved-changes:changed", this.onExternalChange)
    this.element.removeEventListener("unsaved-changes:ready", this.onDependencyReady)

    document.removeEventListener("click", this.onNavigation)
    document.removeEventListener("turbo:before-visit", this.onBeforeVisit)
    window.removeEventListener("beforeunload", this.onBeforeUnload)

    this.formTarget.removeEventListener("turbo:submit-start", this.onSubmitStart)
    this.formTarget.removeEventListener("turbo:submit-end", this.onSubmitEnd)
  }

  dependencyReady(event) {
    if (!this.isInitializing) return

    const { controller } = event.detail || {}

    if (!this.dependencies.some(
      dependency => dependency.identifier === controller
    )) {
      return
    }

    this.finishInitialization()
  }

  finishInitialization() {
    if (!this.isInitializing) return

    const allReady = this.dependencies.every(dependency => {
      const elements = Array.from(this.formTarget.querySelectorAll(`[data-controller~="${dependency.identifier}"]`))

      if (
        this.formTarget.matches(`[data-controller~="${dependency.identifier}"]`)
      ) {
        elements.push(this.formTarget)
      }

      return elements.every(element => element.hasAttribute(dependency.readyAttribute))
    })

    if (!allReady) return

    if (!this.hasUserChanged && !this.externalDirty) {
      this.initialState = this.formState()
      this.isDirty = this.initialDirtyValue
    }

    this.isInitializing = false
    this.handleChange()
  }

  formState() {
    const entries = Array.from(new FormData(this.formTarget).entries())
      .filter(([name, value]) => {
        if (name === "authenticity_token") return false

        if (value instanceof File && !value.name && value.size === 0) {
          return false
        }

        if (name.endsWith("[service_ids][]") && value === "") {
          return false
        }

        return true
      })
      .map(([name, value]) => {
        if (value instanceof File) {
          return [name, `file:${value.name}:${value.size}:${value.lastModified}`]
        }

        return [name, String(value)]
      })

    entries.sort(([nameA, valueA], [nameB, valueB]) => {
      const nameComparison = nameA.localeCompare(nameB)

      return nameComparison || valueA.localeCompare(valueB)
    })

    return JSON.stringify(entries)
  }

  handleChange(event) {
    if (event?.isTrusted) {
      this.hasUserChanged = true
    }

    if (this.isInitializing) {
      if (this.hasUserChanged) {
        this.isDirty = true
      }
      return
    }

    this.isDirty = this.externalDirty || this.formState() !== this.initialState
  }

  markDirty() {
    this.externalDirty = true
    this.isDirty = true
  }

  shouldBlock() {
    this.handleChange()

    return this.isDirty && !this.isSubmitting && !this.isLeaving
  }

  handleNavigation(event) {
    if (!this.shouldBlock() || event.defaultPrevented) return
    if (event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return

    const link = event.target.closest("a[href]")
    if (!link || link.hasAttribute("download") || link.target === "_blank") return
    if (link.dataset.turboMethod || link.dataset.turboConfirm) return

    const url = new URL(link.href, window.location.href)
    if (!["http:", "https:"].includes(url.protocol) || url.origin !== window.location.origin) return
    if (url.href === window.location.href) return

    if (link.dataset.unsavedChangesIgnore === "true") {
      this.isLeaving = true
      return
    }

    event.preventDefault()
    event.stopPropagation()

    this.pendingUrl = url.href
    this.pendingHistory = false
    this.openModal()
  }

  handleBeforeVisit(event) {
    if (!this.shouldBlock()) return

    event.preventDefault()
    this.pendingUrl = event.detail.url
    this.pendingHistory = false
    this.openModal()
  }

  handleBeforeUnload(event) {
    if (!this.shouldBlock()) return

    event.preventDefault()
    event.returnValue = ""
  }

  close() {
    if (!this.shouldBlock()) {
      this.goBack()
      return
    }

    this.pendingUrl = null
    this.pendingHistory = true
    this.openModal()
  }

  goBack() {
    if (this.hasBackUrlValue) {
      Turbo.visit(this.backUrlValue)
    } else {
      window.history.back()
    }
  }

  openModal() {
    this.modalTarget.classList.remove("hidden")
  }

  closeModal() {
    this.modalTarget.classList.add("hidden")
  }

  cancel() {
    this.pendingUrl = null
    this.pendingHistory = false
    this.saveBeforeLeaving = false
    this.closeModal()
  }

  discard() {
    this.isDirty = false
    this.externalDirty = false
    this.isLeaving = true
    this.closeModal()

    if (this.pendingUrl) {
      Turbo.visit(this.pendingUrl)
    } else if (this.pendingHistory) {
      this.goBack()
    }
  }

  save() {
    this.saveBeforeLeaving = true
    this.closeModal()
    this.formTarget.requestSubmit()
  }

  submitStart() {
    this.isSubmitting = true
  }

  submitEnd(event) {
    this.isSubmitting = false

    if (!event.detail.success) {
      this.isDirty = true
      this.saveBeforeLeaving = false
      return
    }

    this.isDirty = false
    this.externalDirty = false
    this.initialState = this.formState()

    const shouldNavigate = this.saveBeforeLeaving && this.streamSaveValue
    this.saveBeforeLeaving = false

    if (!shouldNavigate) {
      this.pendingUrl = null
      this.pendingHistory = false
      return
    }

    this.isLeaving = true

    if (this.pendingUrl) {
      Turbo.visit(this.pendingUrl)
    } else if (this.pendingHistory) {
      this.goBack()
    }
  }
}



import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "message", "date", "startTime", "endTime"]

  static values = {
    url: String,
    mode: String,
    dayOffMessage: String,
    outsideHoursMessage: String,
    errorMessage: String
  }

  connect() {
    this.confirmedKeys = new Set()
    this.pending = null
    this.requestId = 0
    this.previous = this.snapshot()
    this.submitting = false
    this.approvedSubmit = false
    this.submitter = null

    this.onSubmit = this.beforeSubmit.bind(this)

    if (this.modeValue === "form") {
      this.element.addEventListener("submit", this.onSubmit, true)
    }
  }

  disconnect() {
    this.requestId++

    if (this.modeValue === "form") {
      this.element.removeEventListener("submit", this.onSubmit, true)
    }
  }

  snapshot() {
    return {
      date: this.hasDateTarget ? this.dateTarget.value : null,
      start: this.hasStartTimeTarget ? this.startTimeTarget.value : null,
      end: this.hasEndTimeTarget ? this.endTimeTarget.value : null
    }
  }

  normalizeDate(value) {
    const match = value?.match(/^(\d{2})\.(\d{2})\.(\d{4})$/)

    return match
      ? `${match[3]}-${match[2]}-${match[1]}`
      : value
  }

  keyFor(date, start = null, end = null) {
    return JSON.stringify([date, start, end])
  }

  async check({ date, start = null, end = null, onConfirm, onCancel }) {
    if (this.pending) return

    const key = this.keyFor(date, start, end)

    if (this.modeValue !== "calendar" && this.confirmedKeys.has(key)) {
      onConfirm?.()
      return
    }

    const requestId = ++this.requestId
    const url = new URL(this.urlValue, window.location.origin)

    url.searchParams.set("date", date)

    if (start && end) {
      url.searchParams.set("start_time", start)
      url.searchParams.set("end_time", end)
    }

    try {
      const response = await fetch(url, {
        headers: { Accept: "application/json" }
      })

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`)
      }

      const result = await response.json()

      if (requestId !== this.requestId) return

      if (result.status === "ok") {
        onConfirm?.()
        return
      }

      if (result.status === "invalid_time") {
        onCancel?.()
        return
      }

      if (!["day_off", "outside_hours"].includes(result.status)) {
        throw new Error(`Unexpected status: ${result.status}`)
      }

      this.pending = { key, onConfirm, onCancel }

      if (result.status === "day_off") {
        this.messageTarget.textContent = this.dayOffMessageValue
      } else {
        const hours = (result.intervals || []).map(interval => `${interval.start}–${interval.end}`).join(", ")

        this.messageTarget.textContent = this.outsideHoursMessageValue.replace("%{hours}", hours)
      }

      this.modalTarget.classList.remove("hidden")
    } catch (error) {
      if (requestId !== this.requestId) return

      console.error("Working hours check failed:", error)

      onCancel?.()
      window.alert(this.errorMessageValue)
    }
  }

  confirm() {
    if (!this.pending) return

    const pending = this.pending
    this.pending = null

    this.modalTarget.classList.add("hidden")

    if (this.modeValue !== "calendar") {
      this.confirmedKeys.add(pending.key)
    }

    pending.onConfirm?.()
  }

  cancel() {
    if (!this.pending) return

    const pending = this.pending
    this.pending = null

    this.modalTarget.classList.add("hidden")
    pending.onCancel?.()
  }

  checkDate() {
    if (!this.hasDateTarget || this.pending) return

    const current = this.snapshot()
    const previous = this.previous
    const date = this.normalizeDate(current.date)

    if (!date) return

    this.check({
      date,

      onConfirm: () => {
        this.previous = current
      },

      onCancel: () => {
        this.dateTarget.value = previous.date || ""

        const appointment = this.application.getControllerForElementAndIdentifier(this.element, "appointment")

        appointment?.loadSlots()
      }
    })
  }

  checkTime() {
    if (this.pending) return

    if (
      !this.hasDateTarget ||
      !this.hasStartTimeTarget ||
      !this.hasEndTimeTarget
    ) return

    const current = this.snapshot()

    if (!current.start || !current.end || current.end <= current.start) {
      return
    }

    const previous = this.previous

    this.check({
      date: this.normalizeDate(current.date),
      start: current.start,
      end: current.end,

      onConfirm: () => {
        this.previous = current
      },

      onCancel: () => {
        this.startTimeTarget.value = previous.start || ""
        this.endTimeTarget.value = previous.end || ""

        const appointment = this.application.getControllerForElementAndIdentifier(this.element, "appointment")

        appointment?.validateTimes()
      }
    })
  }

  async beforeSubmit(event) {
    if (this.modeValue !== "form") return

    if (this.approvedSubmit) {
      this.approvedSubmit = false
      return
    }

    event.preventDefault()
    event.stopImmediatePropagation()

    if (this.pending || this.submitting) return
    if (!this.element.reportValidity()) return

    const current = this.snapshot()

    if (!current.date || !current.start || !current.end) return
    if (current.end <= current.start) return

    this.submitter = event.submitter
    this.submitting = true

    await this.check({
      date: this.normalizeDate(current.date),
      start: current.start,
      end: current.end,

      onConfirm: () => {
        this.previous = current
        this.submitting = false
        this.approvedSubmit = true
        this.element.requestSubmit(this.submitter?.isConnected ? this.submitter : undefined)
      },

      onCancel: () => {
        this.submitting = false
      }
    })
  }
}

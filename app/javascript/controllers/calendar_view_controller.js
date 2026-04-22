// app/javascript/controllers/calendar_view_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["monthLabel", "calendarDays", "selectedDateLabel", "timeline"]
  static values = { translations: Object, datesWithAppointments: Array, clientId: Number }

  connect() {
    this.t = this.translationsValue
    this.currentDate = new Date()
    this.selectedDate = new Date()
    this.activePopover = null

    this.renderCalendar()
    this.loadAppointments(this.selectedDate)
    this.scrollToToday()
    document.addEventListener("click", this.closePopoverOnClickOutside.bind(this))
    this.startAutoRefresh()
    this.startLiveSlotUpdates()
  }

  disconnect() {
    document.removeEventListener("click", this.closePopoverOnClickOutside)

    if (this.refreshInterval) {
      clearInterval(this.refreshInterval)
    }

    if (this.liveInterval) {
      clearInterval(this.liveInterval)
    }
  }

  renderCalendar() {
    const year = this.currentDate.getFullYear()
    const month = this.currentDate.getMonth()
    const firstDay = new Date(year, month, 1).getDay()
    const daysInMonth = new Date(year, month + 1, 0).getDate()

    const dayNames = [
      this.t.days.sun,
      this.t.days.mon,
      this.t.days.tue,
      this.t.days.wed,
      this.t.days.thu,
      this.t.days.fri,
      this.t.days.sat
    ]

    let html = dayNames.map(day => `<div class="day-name">${day}</div>`).join("")

    for (let i = 0; i < firstDay; i++) {
      html += `<div class="empty-day"></div>`
    }

    for (let day = 1; day <= daysInMonth; day++) {
      const localDate = new Date(year, month, day)

      const dateStr =
        localDate.getFullYear() + "-" +
        String(localDate.getMonth() + 1).padStart(2, "0") + "-" +
        String(localDate.getDate()).padStart(2, "0")

      const isToday = this.isSameDate(localDate, new Date())
      const isSelected = this.isSameDate(localDate, this.selectedDate)
      const hasAppointment = this.datesWithAppointmentsValue.includes(dateStr)

      html += `
        <div class="day ${isToday ? "today" : ""} 
                      ${isSelected ? "selected" : ""} 
                      ${hasAppointment ? "has-appointment" : ""}"
             data-date="${dateStr}"
             data-action="click->calendar-view#selectDate">
          ${day}
        </div>
      `
    }

    this.monthLabelTarget.textContent = this.currentDate.toLocaleDateString(this.t.locale, {
      year: "numeric",
      month: "long"
    })

    this.calendarDaysTarget.innerHTML = html
    this.updateSelectedDateLabel()
    this.updateAddButtonLink()
  }

  updateSelectedDateLabel() {
    this.selectedDateLabelTarget.textContent =
      this.selectedDate.toLocaleDateString(this.t.locale, {
        weekday: "long",
        year: "numeric",
        month: "long",
        day: "numeric"
      })
  }

  updateAddButtonLink() {
    const dateStr = this.formatDate(this.selectedDate)

    const btn = document.querySelector(".add-btn-wrapper a")
    if (btn) {
      btn.href = `/appointments/new?date=${dateStr}`
    }
  }

  prevMonth() {
    this.currentDate.setMonth(this.currentDate.getMonth() - 1)
    this.renderCalendar()
  }

  nextMonth() {
    this.currentDate.setMonth(this.currentDate.getMonth() + 1)
    this.renderCalendar()
  }

  selectDate(event) {
    const dateStr = event.currentTarget.dataset.date

    this.selectedDate = new Date(dateStr + "T00:00:00")
    this.renderCalendar()
    this.loadAppointments(this.selectedDate)
  }

  openNewAppointment(event) {
    const url = new URL(event.target.href);

    if (this.clientIdValue) {
      url.searchParams.set("client_id", this.clientIdValue);
    }

    if (this.selectedDate) {
      url.searchParams.set("date", this.selectedDate);
    }

    event.target.href = url.toString();
  }

  loadAppointments(date) {
    const formatted = this.formatDate(date)

    const today = new Date()
    today.setHours(0, 0, 0, 0)

    const selected = new Date(date)
    selected.setHours(0, 0, 0, 0)

    const isPast = selected < today
    const isToday = selected.getTime() === today.getTime()

    const requests = [
      fetch(`/appointments/by_date?date=${formatted}`).then(r => r.json())
    ]

    if (!isPast) {
      requests.push(
        fetch(`/appointments/free_slots?date=${formatted}`).then(r => r.json())
      )
    }

    Promise.all(requests).then(([appointments, slots = []]) => {

      const normalizedAppointments = appointments.map(a => ({
        ...a,
        start: a.start || a.start_time,
        end: a.end || a.end_time
      }))

      let mergedFreeSlots = []

      if (!isPast) {
        let filteredSlots = slots

        if (isToday) {
          const now = new Date()

          filteredSlots = slots
            .map(slot => {
              let start = this.parseTime(slot.start)
              let end = this.parseTime(slot.end)

              if (end <= now) return null

              if (start < now) {
                start = now
              }

              return {
                start: this.formatTime(start),
                end: this.formatTime(end)
              }
            })
            .filter(Boolean)
        }

        const combinedFreeSlots = this.mergeAdjacentFreeSlots(filteredSlots)
        mergedFreeSlots = this.mergeFreeSlots(combinedFreeSlots, normalizedAppointments)
      }

      this.renderTimeline(normalizedAppointments, mergedFreeSlots)
    })
  }

  renderTimeline(appointments, slots) {
    if (!this.hasTimelineTarget) return

    this.timelineTarget.innerHTML = ""

    const combinedSlots = [
      ...appointments.map(app => ({ type: "booked", data: app })),
      ...slots.map(slot => ({ type: "free", data: slot }))
    ].sort((a, b) =>
      this.parseTime(a.data.start || a.data.start_time) -
      this.parseTime(b.data.start || b.data.start_time)
    )

    combinedSlots.forEach(slot => {
      const el = document.createElement("div")
      el.classList.add("timeline-slot")

      const startDate = this.parseTime(slot.data.start || slot.data.start_time)
      const endDate = this.parseTime(slot.data.end || slot.data.end_time)

      const startTime = this.formatTime(startDate)
      const endTime = this.formatTime(endDate)

      if (slot.type === "booked") {
        el.classList.add("slot-booked")
        el.innerHTML = `
          <div class="slot-content">
            <div class="slot-text">
              ${startTime}–${endTime} — ${slot.data.service} (${slot.data.client_name})
            </div>

            <div class="slot-icon-wrapper">
              <button class="popover-toggle" data-id="${slot.data.id}">✎</button>

              <div class="popover-menu hidden" id="popover-${slot.data.id}">
                <a href="/appointments/${slot.data.id}/edit">${this.t.edit}</a>

                <form action="/appointments/${slot.data.id}" method="post"
                      data-turbo-confirm="${this.t.delete_confirm}">
                  <input type="hidden" name="_method" value="delete">
                  <input type="hidden" name="authenticity_token" value="${this.csrfToken()}">

                  <button type="submit" class="menu-item delete-button">
                    ${this.t.delete}
                  </button>
                </form>
              </div>
            </div>
          </div>
        `
      } else {
        el.classList.add("slot-free")
        el.innerHTML = `
          <div class="slot-content slot-free">
            ${startTime}–${endTime} (${this.t.available})
          </div>
        `
        el.dataset.time = startTime
        el.dataset.action = "click->calendar-view#selectSlot"
      }

      this.timelineTarget.appendChild(el)
    })

    document.querySelectorAll(".popover-toggle").forEach(button => {
      button.addEventListener("click", e => {
        e.stopPropagation()
        this.togglePopover(button.dataset.id)
      })
    })
  }

  mergeAdjacentFreeSlots(slots) {
    if (!slots.length) return []

    const merged = []
    let current = { ...slots[0] }

    for (let i = 1; i < slots.length; i++) {
      const slot = slots[i]

      if (current.end === slot.start) {
        current.end = slot.end
      } else {
        merged.push(current)
        current = { ...slot }
      }
    }

    merged.push(current)
    return merged
  }

  mergeFreeSlots(freeSlots, appointments = []) {
    if (freeSlots.length === 0) return []

    const bookedRanges = appointments.map(a => ({
      start: this.parseTime(a.start || a.start_time),
      end: this.parseTime(a.end || a.end_time)
    }))

    const merged = []

    freeSlots.forEach(slot => {

      let currentStart = this.parseTime(slot.start)
      const currentEnd = this.parseTime(slot.end)

      const overlaps = bookedRanges
        .filter(b => b.start < currentEnd && b.end > currentStart)
        .sort((a, b) => a.start - b.start)

      for (const b of overlaps) {
        if (currentStart < b.start) {
          merged.push({
            start: this.formatTime(currentStart),
            end: this.formatTime(b.start)
          })
        }
        currentStart = b.end > currentStart ? b.end : currentStart
      }

      if (currentStart < currentEnd) {
        merged.push({
          start: this.formatTime(currentStart),
          end: this.formatTime(currentEnd)
        })
      }
    })

    return merged
  }

  parseTime(timeStr) {

    if (!timeStr) return new Date()

    if (timeStr.includes("T")) {
      return new Date(timeStr)
    }

    const [h, m] = timeStr.split(":").map(Number)

    const d = new Date(this.selectedDate)
    d.setHours(h, m, 0, 0)

    return d
  }

  formatTime(date) {
    return date.toLocaleTimeString([], {
      hour: "2-digit",
      minute: "2-digit"
    })
  }

  togglePopover(id) {
    if (this.activePopover) {
      this.activePopover.classList.add("hidden")
      this.activePopover = null
    }

    const menu = document.getElementById(`popover-${id}`)
    if (menu) {
      menu.classList.remove("hidden")
      this.activePopover = menu
    }
  }

  closePopoverOnClickOutside(event) {
    if (
      this.activePopover &&
      !event.target.closest(".popover-menu") &&
      !event.target.closest(".popover-toggle")
    ) {
      this.activePopover.classList.add("hidden")
      this.activePopover = null
    }
  }

  selectSlot(event) {
    const time = event.currentTarget.dataset.time
    const date = this.formatDate(this.selectedDate)
    window.location.href = `/appointments/new?date=${date}&time=${time}`
  }

  scrollToToday() {
    setTimeout(() => {
      const todayEl = this.element.querySelector(".day.today")
      if (todayEl) todayEl.scrollIntoView({ behavior: "smooth", block: "center" })
    }, 300)
  }

  isSameDate(d1, d2) {
    return (
      d1.getFullYear() === d2.getFullYear() &&
      d1.getMonth() === d2.getMonth() &&
      d1.getDate() === d2.getDate()
    )
  }

  formatDate(date) {
    const y = date.getFullYear()
    const m = String(date.getMonth() + 1).padStart(2, "0")
    const d = String(date.getDate()).padStart(2, "0")
    return `${y}-${m}-${d}`
  }

  csrfToken() {
    const meta = document.querySelector("meta[name='csrf-token']")
    return meta ? meta.content : ""
  }

  startAutoRefresh() {
    const now = new Date()

    const delay = (60 - now.getSeconds()) * 1000 - now.getMilliseconds()

    setTimeout(() => {
      this.loadAppointments(this.selectedDate)

      this.refreshInterval = setInterval(() => {
        this.loadAppointments(this.selectedDate)
      }, 60000)

    }, delay)
  }

  startLiveSlotUpdates() {
    const now = new Date()

    const delay = (10 - (now.getSeconds() % 10)) * 1000 - now.getMilliseconds()

    setTimeout(() => {
      this.updateLiveSlots()

      this.liveInterval = setInterval(() => {
        this.updateLiveSlots()
      }, 10000)

    }, delay)
  }

  updateLiveSlots() {
    const today = new Date()
    const selected = new Date(this.selectedDate)

    if (!this.isSameDate(today, selected)) return

    const now = new Date()

    const slots = this.timelineTarget.querySelectorAll(".slot-free")

    slots.forEach(slot => {
      const content = slot.querySelector(".slot-content")
      if (!content) return

      const match = content.textContent.match(/(\d{2}:\d{2})–(\d{2}:\d{2})/)
      if (!match) return

      let [_, startStr, endStr] = match

      let start = this.parseTime(startStr)
      let end = this.parseTime(endStr)

      if (end <= now) {
        slot.remove()
        return
      }

      if (start < now) {
        start = now

        const newStart = this.formatTime(start)

        content.innerHTML = `
          ${newStart}–${this.formatTime(end)} (${this.t.available})
        `
      }
    })
  }
}

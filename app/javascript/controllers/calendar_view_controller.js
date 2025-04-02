import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["monthLabel", "calendarDays", "selectedDateLabel", "timeline"]

  connect() {
    this.currentDate = new Date()
    this.selectedDate = new Date()
    this.activePopover = null

    this.renderCalendar()
    this.loadAppointments(this.selectedDate)
    this.scrollToToday()
    document.addEventListener("click", this.closePopoverOnClickOutside.bind(this))
  }

  disconnect() {
    document.removeEventListener("click", this.closePopoverOnClickOutside)
  }

  renderCalendar() {
    const year = this.currentDate.getFullYear()
    const month = this.currentDate.getMonth()
    const firstDay = new Date(year, month, 1).getDay()
    const daysInMonth = new Date(year, month + 1, 0).getDate()

    const dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    let html = dayNames.map(day => `<div class="day-name">${day}</div>`).join("")

    for (let i = 0; i < firstDay; i++) html += `<div class="empty-day"></div>`

    for (let day = 1; day <= daysInMonth; day++) {
      const date = new Date(year, month, day)
      const isToday = this.isSameDate(date, new Date())
      const isSelected = this.isSameDate(date, this.selectedDate)

      html += `<div class="day ${isToday ? "today" : ""} ${isSelected ? "selected" : ""}"
                  data-date="${date.toISOString()}"
                  data-action="click->calendar-view#selectDate">${day}</div>`
    }

    this.monthLabelTarget.textContent = this.currentDate.toLocaleDateString('uk-UA', {
      year: 'numeric', month: 'long'
    })

    this.calendarDaysTarget.innerHTML = html
    this.updateSelectedDateLabel()
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
    const iso = event.currentTarget.dataset.date
    this.selectedDate = new Date(iso)
    this.renderCalendar()
    this.loadAppointments(this.selectedDate)
  }

  updateSelectedDateLabel() {
    this.selectedDateLabelTarget.textContent = this.selectedDate.toLocaleDateString("uk-UA", {
      weekday: "long", year: "numeric", month: "long", day: "numeric"
    })
  }

  loadAppointments(date) {
    const formatted = this.formatDate(date)
    Promise.all([
      fetch(`/appointments/by_date?date=${formatted}`).then(r => r.json()),
      fetch(`/appointments/free_slots?date=${formatted}`).then(r => r.json())
    ]).then(([appointments, slots]) => {
      const mergedFreeSlots = this.mergeFreeSlots(slots, appointments)
      this.renderTimeline(appointments, mergedFreeSlots)
    })
  }

  renderTimeline(appointments, slots) {
    if (!this.hasTimelineTarget) return

    const timeline = this.timelineTarget
    timeline.innerHTML = ""

    const combinedSlots = [
      ...appointments.map(app => ({ type: 'booked', data: app })),
      ...slots.map(slot => ({ type: 'free', data: slot }))
    ]

    combinedSlots.sort((a, b) => new Date(a.data.start) - new Date(b.data.start))

    combinedSlots.forEach(slot => {
      const el = document.createElement("div")
      const startTime = new Date(slot.data.start).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
      const endTime = new Date(slot.data.end || slot.data.end_time).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })

      el.classList.add("timeline-slot")

      if (slot.type === 'booked') {
        el.classList.add("slot-booked")
        el.innerHTML = `
          <div class="slot-content">
            <div class="slot-text">
              ${startTime}–${endTime} — ${slot.data.service} (${slot.data.client_name})
            </div>
            <div class="slot-icon-wrapper">
              <button class="popover-toggle" data-id="${slot.data.id}">✎</button>
              <div class="popover-menu hidden" id="popover-${slot.data.id}">
                <a href="/appointments/${slot.data.id}/edit">✏️ Edit</a>
                <form action="/appointments/${slot.data.id}" method="post" data-turbo-confirm="Are you sure you want to delete this appointment?">
                  <input type="hidden" name="_method" value="delete" />
                  <input type="hidden" name="authenticity_token" value="${this.csrfToken()}" />
                  <button type="submit" class="menu-item delete-button">🗑 Delete</button>
                </form>
              </div>
            </div>
          </div>
        `
      } else {
        el.classList.add("slot-free")
        el.innerHTML = `
          <div class="slot-content slot-free">
            ${startTime}–${endTime} (Available)
          </div>
        `
        el.dataset.time = startTime
        el.dataset.action = "click->calendar-view#selectSlot"
      }

      timeline.appendChild(el)
    })

    document.querySelectorAll(".popover-toggle").forEach(button => {
      button.addEventListener("click", e => {
        e.stopPropagation()
        this.togglePopover(button.dataset.id)
      })
    })
  }

  // mergeFreeSlots(slots) {
  //   if (slots.length === 0) return []
  //   const sorted = [...slots].sort((a, b) => new Date(a.start) - new Date(b.start))

  //   const merged = []
  //   let current = { ...sorted[0] }

  //   for (let i = 1; i < sorted.length; i++) {
  //     const prevEnd = new Date(current.end)
  //     const currStart = new Date(sorted[i].start)

  //     if (prevEnd.getTime() === currStart.getTime()) {
  //       current.end = sorted[i].end
  //     } else {
  //       merged.push(current)
  //       current = { ...sorted[i] }
  //     }
  //   }

  //   merged.push(current)
  //   return merged
  // }

  mergeFreeSlots(freeSlots, appointments = []) {
    if (freeSlots.length === 0) return []
  
    // Перетворення дат для обробки
    const bookedRanges = appointments
      .map(a => ({
        start: new Date(a.start),
        end: new Date(a.end)
      }))
      .filter(a => a.start && a.end)
  
    const merged = []
  
    freeSlots.forEach(slot => {
      let currentStart = new Date(slot.start)
      const currentEnd = new Date(slot.end)
  
      const overlaps = bookedRanges
        .filter(b => b.start < currentEnd && b.end > currentStart)
        .sort((a, b) => a.start - b.start)
  
      for (const b of overlaps) {
        if (currentStart < b.start) {
          merged.push({ start: new Date(currentStart), end: new Date(b.start) })
        }
        currentStart = b.end > currentStart ? b.end : currentStart
      }
  
      if (currentStart < currentEnd) {
        merged.push({ start: new Date(currentStart), end: currentEnd })
      }
    })
  
    // Додатково зливаємо сусідні після вирізання
    const finalMerged = []
    let current = null
  
    for (const slot of merged.sort((a, b) => new Date(a.start) - new Date(b.start))) {
      if (!current) {
        current = { ...slot }
        continue
      }
  
      if (new Date(current.end).getTime() === new Date(slot.start).getTime()) {
        current.end = slot.end
      } else {
        finalMerged.push(current)
        current = { ...slot }
      }
    }
  
    if (current) finalMerged.push(current)
  
    return finalMerged
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
      !event.target.classList.contains("popover-toggle")
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
    return d1.getFullYear() === d2.getFullYear() &&
           d1.getMonth() === d2.getMonth() &&
           d1.getDate() === d2.getDate()
  }

  formatDate(date) {
    const localDate = new Date(date.getTime() - date.getTimezoneOffset() * 60000)
    return localDate.toISOString().split("T")[0]
  }

  csrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]')
    return meta ? meta.content : ""
  }
}

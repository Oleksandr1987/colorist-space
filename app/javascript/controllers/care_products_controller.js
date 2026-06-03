// controllers/care_products_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["list", "modal", "input", "total",  "newForm", "newName", "newPrice", "search", "productsList"]

  connect() {
    this.products = this.load()
    this.render()

    window.dispatchEvent(
      new CustomEvent("care-products:changed")
    )
  }

  openModal() {
    this.modalTarget.classList.remove("hidden")
  }

  closeModal() {
    this.modalTarget.classList.add("hidden")
  }

  stop(event) {
    event.stopPropagation()
  }

  addProduct(event) {
    const button = event.currentTarget

    const existing = this.products.find(
      p => p.service_id == button.dataset.id
    )

    if (existing) {
      existing.qty += 1
    } else {
      this.products.push({
        service_id: button.dataset.id,
        name: button.dataset.name,
        price: parseFloat(button.dataset.price),
        qty: 1
      })
    }

    this.render()
    this.save()
    this.closeModal()
  }

  load() {
    try {
      let data = JSON.parse(this.inputTarget.value || "[]")

      if (typeof data === "string") {
        data = JSON.parse(data)
      }

      return Array.isArray(data) ? data : []
    } catch {
      return []
    }
  }

  save() {
    this.inputTarget.value = JSON.stringify(this.products)

    window.dispatchEvent(
      new CustomEvent("care-products:changed")
    )
  }

  render() {
    this.listTarget.innerHTML = ""

    let total = 0

    this.products.forEach((item, index) => {
      const lineTotal = item.price * item.qty

      total += lineTotal

      this.listTarget.insertAdjacentHTML(
        "beforeend",
        `
          <div class="care-product-row">

            <div class="care-product-info">

              <div class="care-product-name">
                ${item.name}
              </div>

              <span class="care-product-price">
                ${item.price} ₴ × ${item.qty}
                = ${lineTotal} ₴
              </span>

            </div>

            <div class="qty-control">

              <button
                type="button"
                data-index="${index}"
                data-action="click->care-products#decreaseQty">

                −

              </button>

              <span class="qty-value">
                ${item.qty}
              </span>

              <button
                type="button"
                data-index="${index}"
                data-action="click->care-products#increaseQty">

                +

              </button>

            </div>

            <button
              type="button"
              class="remove-care-product"
              data-index="${index}"
              data-action="click->care-products#remove">

              ×

            </button>

          </div>
        `
      )
    })

    this.totalTarget.textContent = `${total} ₴`
  }

  increaseQty(event) {
    const index = parseInt(
      event.currentTarget.dataset.index
    )

    this.products[index].qty += 1

    this.render()
    this.save()
  }

  decreaseQty(event) {
    const index = parseInt(
      event.currentTarget.dataset.index
    )

    if (this.products[index].qty <= 1) {
      return
    }

    this.products[index].qty -= 1

    this.render()
    this.save()
  }

  changeQty(event) {
    const index = parseInt(
      event.currentTarget.dataset.index
    )

    const qty = parseInt(event.currentTarget.value)

    this.products[index].qty =
      isNaN(qty) || qty < 1 ? 1 : qty

    this.render()
    this.save()
  }

  showNewForm() {
    this.newFormTarget.classList.remove("hidden")
  }

  hideNewForm() {
    this.newFormTarget.classList.add("hidden")
  }

  async createProduct() {
    const name = this.newNameTarget.value.trim()
    const price = parseFloat(this.newPriceTarget.value)

    if (!name || isNaN(price)) {
      return
    }

    const token =
      document.querySelector(
        "meta[name='csrf-token']"
      ).content

    const response = await fetch(
      "/services/create_care_product",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": token,
          "Accept": "application/json"
        },
        body: JSON.stringify({
          service: {
            subtype: name,
            price: price,
            service_type: "care_product"
          }
        })
      }
    )

    if (!response.ok) return

    const product = await response.json()

    this.appendProductToModal(product)

    const existing = this.products.find(
      p => p.service_id == product.id
    )

    if (existing) {
      existing.qty += 1
    } else {
      this.products.push({
        service_id: product.id,
        name: product.name,
        price: product.price,
        qty: 1
      })
    }

    this.render()
    this.save()

    this.newNameTarget.value = ""
    this.newPriceTarget.value = ""

    this.hideNewForm()
    this.closeModal()
  }

  search() {
    const query =
      this.searchTarget.value.toLowerCase()

    this.productsListTarget
      .querySelectorAll(".care-product-option")
      .forEach(item => {
        item.classList.toggle(
          "hidden",
          !item.textContent
            .toLowerCase()
            .includes(query)
        )
      })
  }

  appendProductToModal(product) {
    this.productsListTarget.insertAdjacentHTML(
      "beforeend",
      `
        <div class="care-product-option">

          <div>
            <strong>${product.name}</strong>
            <small>${product.price} ₴</small>
          </div>

          <button type="button"
                  data-action="click->care-products#addProduct"
                  data-id="${product.id}"
                  data-name="${product.name}"
                  data-price="${product.price}">
            +
          </button>

        </div>
      `
    )
  }

  remove(event) {
    const index = parseInt(
      event.currentTarget.dataset.index
    )

    this.products.splice(index, 1)

    this.render()
    this.save()
  }
}

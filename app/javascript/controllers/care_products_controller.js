// controllers/care_products_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "list",
    "modal",
    "input",
    "total",

    "newForm",
    "newBrand",
    "newName",
    "newCategory",
    "newPrice",

    "search",
    "productsList"
  ]

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
      p => p.care_product_id == button.dataset.id
    )

    if (existing) {
      existing.qty += 1
    } else {
      this.products.push({
        care_product_id: button.dataset.id,
        name: button.dataset.name,
        price: parseFloat(button.dataset.price),
        qty: 1,
        stock: parseInt(button.dataset.stock, 10) || 0
      })
    }

    this.render()
    this.save()
    this.closeModal()
  }

  async createProduct() {
    const brand =
      this.newBrandTarget.value.trim()

    const name =
      this.newNameTarget.value.trim()

    const category =
      this.newCategoryTarget.value.trim()

    const price =
      parseFloat(this.newPriceTarget.value)

    if (!name || isNaN(price)) {
      return
    }

    const token =
      document.querySelector(
        "meta[name='csrf-token']"
      ).content

    const response = await fetch(
      "/care_products",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": token,
          "Accept": "application/json"
        },
        body: JSON.stringify({
          care_product: {
            brand: brand,
            name: name,
            category: category,
            sale_price: price
          }
        })
      }
    )

    if (!response.ok) return

    const product = await response.json()

    this.appendProductToModal(product)

    this.products.push({
      care_product_id: productId,
      name: productName,
      price: price,
      qty: 1,
      stock: parseInt(button.dataset.stock, 10) || 0
    })

    this.render()
    this.save()

    this.newBrandTarget.value = ""
    this.newNameTarget.value = ""
    this.newCategoryTarget.value = ""
    this.newPriceTarget.value = ""

    this.hideNewForm()
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

  filterCategory(event) {
    const category = event.currentTarget.dataset.category

    document
      .querySelectorAll(".filter-button")
      .forEach(button => {
        button.classList.remove("active")
      })

    event.currentTarget.classList.add("active")

    this.productsListTarget
      .querySelectorAll(".care-product-option")
      .forEach(item => {

        if (
          category === "" ||
          item.dataset.category === category
        ) {
          item.classList.remove("hidden")
        } else {
          item.classList.add("hidden")
        }
      })
  }

  render() {
    this.listTarget.innerHTML = ""

    let total = 0

    // this.products.forEach((item, index) => {
    //   const lineTotal = item.price * item.qty

    //   total += lineTotal

    this.products.forEach((item, index) => {
      const lineTotal = item.price * item.qty

      const availableStock =
        parseInt(item.stock || 0, 10) +
        parseInt(item.qty || 0, 10)

      total += lineTotal

      this.listTarget.insertAdjacentHTML(
        "beforeend",
        `
          <div class="care-product-row">

            <div class="care-product-info">

              <div class="care-product-name">
                ${item.name}
              </div>

              <div class="care-product-price">
                ${item.price} ₴ × ${item.qty}
                = ${lineTotal} ₴
              </div>

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
                data-action="click->care-products#increaseQty"
                ${
                  item.qty >= availableStock
                    ? "disabled"
                    : ""
                }>

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

  // increaseQty(event) {
  //   const index = parseInt(
  //     event.currentTarget.dataset.index,
  //     10
  //   )

  //   const product =
  //     this.products[index]

  //   if (!product) return

  //   const stock =
  //     parseInt(product.stock || 0, 10)

  //   if (product.qty >= stock) {
  //     alert(
  //       `Only ${stock} item(s) left in stock`
  //     )

  //     return
  //   }

  //   product.qty += 1

  //   this.render()
  //   this.save()
  // }

  increaseQty(event) {
  const index = parseInt(
    event.currentTarget.dataset.index,
    10
  )

  const product =
    this.products[index]

  if (!product) return

  const availableStock =
    parseInt(product.stock || 0, 10) +
    parseInt(product.qty || 0, 10)

  if (product.qty >= availableStock) {
    alert(
      `Only ${availableStock} item(s) available`
    )

    return
  }

  product.qty += 1

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
        <div class="care-product-option"
            data-category="${product.category || ""}">

          <div>

            <strong>
              ${product.brand || ""}
            </strong>

            <div>
              ${product.name}
            </div>

            <small>
              ${product.category || ""}
            </small>

            <br>

            <small>
              ${product.sale_price} ₴
            </small>

          </div>

          <button type="button"
                  data-action="click->care-products#addProduct"
                  data-id="${product.id}"
                  data-name="${product.name}"
                  data-price="${product.sale_price}"
                  data-stock="${product.stock_quantity || 0}">
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

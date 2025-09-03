# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "inputmask", to: "https://ga.jspm.io/npm:inputmask@5.0.8/dist/inputmask.es6.js"
pin "litepicker", to: "https://cdn.jsdelivr.net/npm/litepicker@2.0.12/dist/litepicker.js"

// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

if ("serviceWorker" in navigator) {
    // Register a service worker hosted at the root of the
    // application using the default scope.
    navigator.serviceWorker.register("/service-worker.js").then(
        (registration) => {
            console.log("Service Worker registration succeeded:", registration);
        },
        (error) => {
            console.error('Service Worker registration failed: ${error}');
        }
    );
  } else {
    console.log("Service workers are not supported.");
  }

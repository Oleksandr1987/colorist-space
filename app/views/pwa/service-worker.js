if ('serviceWorker' in navigator) {
  // Register the service worker
  navigator.serviceWorker.register('/service-worker.js')
    .then(function(registration) {
      console.log('Service Worker registered with scope:', registration.scope);
    })
    .catch(function(error) {
      console.log('Service Worker registration failed:', error);
    });
}
// The install event is fired when the service worker is first installed
self.addEventListener('install', function(event) {
  console.log('Service Worker installed');
});

// The activate event is fired after the install event when the service worker is actually controlling the page
self.addEventListener('activate', function(event) {
  console.log('Service Worker activated');
});

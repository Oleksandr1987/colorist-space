// Add a service worker for processing Web Push notifications:

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open("v1").then((cache) => {
      return cache.addAll([
        "/",
        "/assets/application-8b3e8d3c.css",
        "/assets/application-4e7b3c7d.js",
        "/offline.html",
      ]);
    })
  );
});

self.addEventListener("activate", (event) => {
  console.log("Service Worker activating.");
});

self.addEventListener("fetch", (event) => {
  event.respondWith(
    caches.match(event.request).then((response) => {
      if (response !== undefined) {
        return response;
      } else {
        return fetch(event.request)
      .then((response) => {
        let responseClone = response.clone();

        caches.open("v1").then((cache) => {
          cache.put(event.request, responseClone);
        });
        return response;
      })
      .catch(() => caches.match("/offline.html"));
     }
    }),
  );
});

self.addEventListener("push", async (event) => {
  const { title, options } = await event.data.json();
  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener("notificationclick", function(event) {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: "window" }).then((clientList) => {
      for (let i = 0; i < clientList.length; i++) {
        let client = clientList[i];
        let clientPath = (new URL(client.url)).pathname;

        if (clientPath == event.notification.data.path && "focus" in client) {
          return client.focus();
        }
      }

      if (clients.openWindow) {
        return clients.openWindow(event.notification.data.path);
      }
    })
  );
});
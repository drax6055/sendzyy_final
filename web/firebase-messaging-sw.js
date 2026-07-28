importScripts('https://www.gstatic.com/firebasejs/10.13.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.0/firebase-messaging-compat.js');

// Sendzyy Firebase Web Configuration
const firebaseConfig = {
  apiKey: "AIzaSyD-PkzV-8Ruj4ExeiTYkDTo4hYEVaCBi48",
  authDomain: "sendzyy.firebaseapp.com",
  projectId: "sendzyy",
  storageBucket: "sendzyy.firebasestorage.app",
  messagingSenderId: "316353739480",
  appId: "1:316353739480:web:fed74e4dfc3c49f002b5ad",
  measurementId: "G-LNK86SE44R"
};

firebase.initializeApp(firebaseConfig);

const messaging = firebase.messaging();

// Background Push Notification Handler for Web Browser
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Background notification payload:', payload);

  const title = payload.notification?.title || payload.data?.title || 'Sendzyy Notification';
  const options = {
    body: payload.notification?.body || payload.data?.body || '',
    icon: '/favicon.png',
    badge: '/favicon.png',
    data: payload.data || {}
  };

  self.registration.showNotification(title, options);
});

// Click event when user taps the browser notification
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if (client.url && 'focus' in client) {
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow('/');
      }
    })
  );
});

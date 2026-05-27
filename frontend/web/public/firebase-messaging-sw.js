/**
 * Firebase Cloud Messaging Service Worker
 * Handles background push notifications when the web app is not active.
 *
 * This file is served from /firebase-messaging-sw.js
 * IMPORTANT: This service worker receives Firebase config via URL search params
 * from the main app when it registers the service worker.
 *
 * Registration is done in push-notification.service.ts via:
 *   navigator.serviceWorker.register('/firebase-messaging-sw.js', { scope: '/firebase-messaging-sw.js' })
 */
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

// Firebase config passed from main app via URL search params
const urlParams = new URL(self.location.href).searchParams;
const firebaseConfig = {
  apiKey: urlParams.get('apiKey') || '',
  authDomain: urlParams.get('authDomain') || '',
  projectId: urlParams.get('projectId') || '',
  storageBucket: urlParams.get('storageBucket') || '',
  messagingSenderId: urlParams.get('messagingSenderId') || '',
  appId: urlParams.get('appId') || '',
};

const isConfigured = !!(
  firebaseConfig.apiKey &&
  firebaseConfig.projectId &&
  firebaseConfig.messagingSenderId
);

self.addEventListener('install', (event) => {
  console.log('[FCM SW] Service worker installed');
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  console.log('[FCM SW] Service worker activated');
  event.waitUntil(self.clients.claim());
});

if (isConfigured) {
  try {
    const app = firebase.initializeApp(firebaseConfig);
    const messaging = firebase.messaging();

    messaging.onBackgroundMessage((payload) => {
      console.log('[FCM SW] Background message received:', payload);

      const title = payload.notification?.title ?? 'VNALO';
      const body = payload.notification?.body ?? '';
      const data = payload.data ?? {};

      const notificationOptions = {
        body,
        icon: '/icons.svg',
        badge: '/favicon.png',
        tag: data.type ?? 'default',
        data,
        requireInteraction: data.type === 'chat_message',
        vibrate: [200, 100, 200],
      };

      self.registration.showNotification(title, notificationOptions).catch((err) => {
        console.error('[FCM SW] Failed to show notification:', err);
      });
    });

    console.log('[FCM SW] Firebase messaging initialized successfully.');
  } catch (err) {
    console.warn('[FCM SW] Firebase initialization failed:', err);
  }
} else {
  console.warn('[FCM SW] Firebase not configured. Set VITE_FIREBASE_* env vars in .env');
}

self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  const data = event.notification.data ?? {};
  const type = data.type ?? '';
  let targetUrl = '/';

  switch (type) {
    case 'friend_request':
    case 'friend_accepted':
    case 'friend_declined':
      targetUrl = '/contacts';
      break;
    case 'chat_message':
      targetUrl = data.conversationId ? `/chat/${data.conversationId}` : '/chat';
      break;
    default:
      targetUrl = '/chat';
  }

  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if (client.url.includes(self.location.origin) && 'focus' in client) {
          client.navigate(self.location.origin + targetUrl);
          return client.focus();
        }
      }
      if (self.clients.openWindow) {
        return self.clients.openWindow(targetUrl);
      }
    })
  );
});

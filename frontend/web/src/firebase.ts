import { initializeApp, getApps } from 'firebase/app';
import type { FirebaseApp } from 'firebase/app';
import { getMessaging, isSupported } from 'firebase/messaging';
import type { Messaging } from 'firebase/messaging';

const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY,
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN,
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID,
  storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID,
  appId: import.meta.env.VITE_FIREBASE_APP_ID,
};

let app: FirebaseApp | null = null;
let messaging: Messaging | null = null;

function isConfigured(): boolean {
  return !!(
    firebaseConfig.apiKey &&
    firebaseConfig.apiKey !== 'your_firebase_api_key' &&
    firebaseConfig.projectId &&
    firebaseConfig.messagingSenderId
  );
}

export async function initFirebaseMessaging(): Promise<{ app: FirebaseApp; messaging: Messaging } | null> {
  if (!isConfigured()) {
    console.warn('[FCM] Firebase is not configured. Set VITE_FIREBASE_* env vars.');
    return null;
  }

  if (!app) {
    app = getApps().length > 0 ? getApps()[0] : initializeApp(firebaseConfig);
  }

  const supported = await isSupported();
  if (!supported) {
    console.warn('[FCM] Browser does not support FCM. Push notifications disabled.');
    return null;
  }

  messaging = getMessaging(app);

  // Register the service worker with Firebase config params
  try {
    const swUrl = '/firebase-messaging-sw.js?' + new URLSearchParams({
      apiKey: firebaseConfig.apiKey,
      authDomain: firebaseConfig.authDomain,
      projectId: firebaseConfig.projectId,
      storageBucket: firebaseConfig.storageBucket,
      messagingSenderId: firebaseConfig.messagingSenderId,
      appId: firebaseConfig.appId,
    }).toString();

    await navigator.serviceWorker.register(swUrl);
    console.log('[FCM] Service worker registered for push notifications.');
  } catch (err) {
    console.warn('[FCM] Service worker registration failed:', err);
  }

  return { app, messaging };
}

export function getMessagingInstance(): Messaging | null {
  return messaging;
}

export function isFirebaseConfigured(): boolean {
  return isConfigured();
}

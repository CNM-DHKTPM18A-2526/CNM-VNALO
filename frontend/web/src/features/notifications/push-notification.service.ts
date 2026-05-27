import { API_BASE_URL } from '../../api.client';
import { isFirebaseConfigured, initFirebaseMessaging } from '../../firebase';
import { getToken, onMessage } from 'firebase/messaging';
import type { Messaging } from 'firebase/messaging';

export interface NotificationPayload {
  type: string;
  [key: string]: string | undefined;
}

interface FcmTokenPayload {
  notification?: {
    title?: string;
    body?: string;
  };
  data?: Record<string, string>;
}

/**
 * Handles FCM push notifications for the web app.
 *
 * Flow:
 * 1. init() → request permission, get FCM token, register with backend
 * 2. listenForegroundMessages() → show in-app notification when app is open
 * 3. Service worker (firebase-messaging-sw.js) → show browser notification when app is closed
 */
export class PushNotificationService {
  private static instance: PushNotificationService;
  private fcmToken: string | null = null;
  private permissionState: NotificationPermission = 'default';

  private constructor() {}

  static getInstance(): PushNotificationService {
    if (!PushNotificationService.instance) {
      PushNotificationService.instance = new PushNotificationService();
    }
    return PushNotificationService.instance;
  }

  get isEnabled(): boolean {
    return this.permissionState === 'granted' && !!this.fcmToken;
  }

  async init(accessToken?: string): Promise<void> {
    if (!isFirebaseConfigured()) {
      console.warn('[PushNotification] Firebase not configured — skipping.');
      return;
    }

    this.permissionState = Notification.permission;

    if (this.permissionState === 'denied') {
      console.warn('[PushNotification] Notification permission denied.');
      return;
    }

    const result = await initFirebaseMessaging();
    if (!result) return;

    const { messaging } = result;

    if (this.permissionState !== 'granted') {
      const permission = await Notification.requestPermission();
      this.permissionState = permission;
      if (permission !== 'granted') {
        console.warn('[PushNotification] Permission not granted.');
        return;
      }
    }

    try {
      const vapidKey = import.meta.env.VITE_FIREBASE_VAPID_KEY as string | undefined;
      this.fcmToken = vapidKey
        ? await getToken(messaging, { vapidKey })
        : await getToken(messaging);
      console.log('[PushNotification] FCM token obtained:', this.fcmToken?.slice(0, 16) + '...');
    } catch (err) {
      console.error('[PushNotification] Failed to get FCM token:', err);
      return;
    }

    if (accessToken) {
      await this.registerToken(accessToken);
    }

    this.listenForegroundMessages(messaging);
  }

  async registerAfterLogin(accessToken: string): Promise<void> {
    if (!this.fcmToken) {
      await this.init(accessToken);
      return;
    }
    await this.registerToken(accessToken);
  }

  private listenForegroundMessages(messaging: Messaging): void {
    onMessage(messaging, (payload: FcmTokenPayload) => {
      console.log('[PushNotification] Foreground message received:', payload);

      const title = payload.notification?.title ?? 'VNALO';
      const body = payload.notification?.body ?? '';
      const data: NotificationPayload = {
        type: payload.data?.type ?? 'default',
        ...(payload.data ?? {}),
      };

      if (Notification.permission === 'granted') {
        const notification = new Notification(title, {
          body,
          icon: '/icons.svg',
          badge: '/favicon.png',
          tag: data.type ?? 'default',
        });

        notification.onclick = () => {
          window.focus();
          notification.close();
          this.handleNotificationTap(data);
        };
      }

      window.dispatchEvent(new CustomEvent('vnalo:push-notification', { detail: { payload, data } }));
    });
  }

  private handleNotificationTap(data: NotificationPayload): void {
    const type = data.type;

    switch (type) {
      case 'friend_request':
      case 'friend_accepted':
      case 'friend_declined':
        window.dispatchEvent(new CustomEvent('vnalo:navigate', { detail: { path: '/contacts' } }));
        break;
      case 'chat_message':
        if (data.conversationId) {
          window.dispatchEvent(new CustomEvent('vnalo:navigate', {
            detail: { path: `/chat/${data.conversationId}`          }
          }));
        }
        break;
      default:
        window.dispatchEvent(new CustomEvent('vnalo:navigate', { detail: { path: '/chat' } }));
    }
  }

  private async registerToken(accessToken: string): Promise<void> {
    if (!this.fcmToken) return;

    try {
      const response = await fetch(`${API_BASE_URL}/notifications/devices`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${accessToken}`,
        },
        body: JSON.stringify({
          deviceId: this.getWebDeviceId(),
          platform: 'WEB',
          fcmToken: this.fcmToken,
        }),
      });

      if (response.ok) {
        console.log('[PushNotification] Token registered with backend.');
      } else {
        console.warn('[PushNotification] Token registration failed: HTTP', response.status);
      }
    } catch (err) {
      console.error('[PushNotification] Token registration error:', err);
    }
  }

  private getWebDeviceId(): string {
    const key = 'vnalo_web_device_id';
    let deviceId = localStorage.getItem(key);
    if (!deviceId) {
      deviceId = `web_${Date.now()}_${Math.random().toString(36).substring(2, 11)}`;
      localStorage.setItem(key, deviceId);
    }
    return deviceId;
  }
}

export const pushNotificationService = PushNotificationService.getInstance();

import admin from 'firebase-admin';

/// Push sending via FCM. Needs FIREBASE_SERVICE_ACCOUNT (the JSON from
/// Firebase console → Project settings → Service accounts → Generate key)
/// pasted into Railway as one env var. Absent or broken → pushes silently off,
/// nothing else affected.
const SA = process.env.FIREBASE_SERVICE_ACCOUNT || '';

let ready = false;
try {
  if (SA) {
    admin.initializeApp({ credential: admin.credential.cert(JSON.parse(SA)) });
    ready = true;
  }
} catch (e) {
  console.error('[push] service account rejected:', (e as Error).message);
}

export const pushEnabled = ready;

export function sendPush(token: string, title: string, body: string): void {
  if (!ready || !token) return;
  void admin
    .messaging()
    .send({
      token,
      notification: { title, body },
      apns: { payload: { aps: { sound: 'default' } } },
    })
    .catch(() => {/* dead token / transient — never fatal */});
}

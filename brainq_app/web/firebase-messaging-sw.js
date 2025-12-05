// Give the browser access to Firebase Messaging.
importScripts('https://www.gstatic.com/firebasejs/9.22.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.22.1/firebase-messaging-compat.js');

// Initialize the Firebase app in the service worker using the generated config.
firebase.initializeApp({
  apiKey: 'AIzaSyAEIXRSormb5qxLADP3HkXo3er5JmPLJpI',
  appId: '1:75770336772:web:3fda30688eb0716410c751',
  messagingSenderId: '75770336772',
  projectId: 'brainqapp-9da8e',
  authDomain: 'brainqapp-9da8e.firebaseapp.com',
  storageBucket: 'brainqapp-9da8e.firebasestorage.app',
});

// Retrieve an instance of Firebase Messaging so it can handle background messages.
const messaging = firebase.messaging();

// Optional: Customize background notification handling
messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  const notificationTitle = payload.notification?.title || 'Background Message';
  const notificationOptions = {
    body: payload.notification?.body || '',
    icon: '/favicon.png', // Optional: path to your icon
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});

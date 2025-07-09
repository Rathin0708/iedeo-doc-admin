# Ideo Health Admin Panel

A Flutter web admin panel for managing Ideo Health documentation.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Setup Instructions

### Google Sign-In Configuration

To enable Google Sign-In, you need to configure your OAuth client ID:

1. **Get your Google OAuth Client ID:**
    - Go to [Google Cloud Console](https://console.cloud.google.com/)
    - Select your project: `iedeo-43e6a`
    - Navigate to APIs & Services > Credentials
    - Look for "OAuth 2.0 Client IDs" section
    - Find the client ID for "Web application" (it should look like:
      `439628553649-xxxxxxxxxx.apps.googleusercontent.com`)
    - If you don't see one, click "Create Credentials" > "OAuth client ID" > "Web application"

2. **Update web/index.html:**
    - Replace `439628553649-placeholder.apps.googleusercontent.com` with your actual client ID:
   ```html
   <meta name="google-signin-client_id" content="439628553649-YOUR_ACTUAL_CLIENT_ID.apps.googleusercontent.com">
   ```

3. **Important Notes:**
    - The placeholder client ID prevents app crashes but Google Sign-In won't work
    - You must use the actual client ID from your Google Cloud Console
    - Make sure your domain is authorized in the OAuth client settings

### Firebase Configuration

Firebase is already configured with these settings:

- Project ID: `iedeo-43e6a`
- Auth Domain: `iedeo-43e6a.firebaseapp.com`
- Storage Bucket: `iedeo-43e6a.firebasestorage.app`

### Running the App

```bash
flutter run -d chrome
```

### Features

- Admin authentication (Email/Password + Google Sign-In)
- Firebase Firestore integration
- Offline persistence
- Instant authentication with background sync
- Admin dashboard
- Role-based access control

### Troubleshooting

**Google Sign-In Error: "ClientID not set"**

- Ensure you've added the correct client ID to `web/index.html`
- The client ID should be your OAuth 2.0 Web Client ID from Google Cloud Console
- Make sure the domain is authorized in your OAuth client settings

**Firebase Connection Issues**

- Check your internet connection
- Verify Firebase project settings
- The app works offline with cached data

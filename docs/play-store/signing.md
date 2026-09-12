# Android Play upload signing

Gold Rush should use Play App Signing with a separate upload key. Google Play holds the app-signing key; the developer keeps only the upload key used to authenticate new bundles.

Create a dedicated RSA upload key (2048 bits or stronger) and register its certificate in Play Console. Keep the keystore outside Git.

Recommended GitHub Actions secret names:
- `ANDROID_UPLOAD_KEYSTORE_BASE64`
- `ANDROID_UPLOAD_KEYSTORE_PASSWORD`
- `ANDROID_UPLOAD_KEY_ALIAS`
- `ANDROID_UPLOAD_KEY_PASSWORD`

The keystore value should be the base64-encoded bytes of the `.jks` file, not a path on a local machine. Never commit the keystore or any password to this repository.

Play App Signing reference: https://support.google.com/googleplay/android-developer/answer/9842756

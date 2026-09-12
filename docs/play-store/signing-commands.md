# Upload-key setup commands

Generate an upload key on a secure machine with Java installed:

```bash
keytool -genkeypair -v -keystore goldrush-upload.jks -alias goldrush-upload -keyalg RSA -keysize 4096 -validity 10000
```

Export the public certificate Play may ask you to register:

```bash
keytool -export -rfc -keystore goldrush-upload.jks -alias goldrush-upload -file goldrush-upload-certificate.pem
```

Encode the keystore for GitHub Actions on macOS/Linux:

```bash
base64 < goldrush-upload.jks | tr -d '\n'
```

On Windows PowerShell:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("goldrush-upload.jks"))
```

Add the resulting value and passwords to GitHub repository Actions secrets using the names in `signing.md`. Keep an offline backup of the `.jks` file and its passwords. The upload key can be reset through Play Console if it is lost; the Play-managed app-signing key is separate.

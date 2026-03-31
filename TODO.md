# Flutter Firebase CI/CD Setup Progress

## Completed:
- [x] Created custom `.github/workflows/flutter-cd.yml` (test + Firebase deploy).
- [x] Firebase project initialized (sandhere-web).

## Critical Next: GCP Service Account (Fix 404 Error)
1. Go to [GCP Console IAM](https://console.cloud.google.com/iam-admin/serviceaccounts?project=sandhere-web).
2. Create service account:
   ```
   Name: github-action-1141712509
   ID: github-action-1141712509
   Description: GitHub Actions Firebase deploy
   ```
3. Grant roles: `Firebase Hosting Admin`, `Firebase Rules Admin`, `Service Account User`.
4. Create key (JSON), download `key.json`.
5. Base64 encode:
   ```
   base64 -w 0 key.json  # Copy output
   ```
6. GitHub repo Settings > Secrets > New secret:
   - Name: `FIREBASE_SERVICE_ACCOUNT_SANDHERE_WEB`
   - Value: base64 string.

## Other Steps:
1. Delete auto Firebase workflows: `rm .github/workflows/firebase-hosting-*.yml && git add && git commit -m "Remove auto Firebase workflows" && git push`.
2. Push workflow changes → auto test/deploy on main.

## Verify:
- Actions tab shows success.
- Firebase Hosting: https://sandhere-web.web.app or configured URL.
- Local: `flutter build web && firebase deploy --only hosting`.

Run `flutter test` (passed!).


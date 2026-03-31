# Flutter CI/CD Setup Progress

## Completed:
- [x] Created `.github/workflows/flutter-cd.yml` for test/build/deploy to Vercel (Firebase optional).

## Next Steps:
1. Add secrets to GitHub repo Shiv14Shivam/front:
   - `VERCEL_TOKEN`: From Vercel dashboard > Tokens.
   - `ORG_ID` & `PROJECT_ID`: From Vercel project settings (if not using Git integration).
   - Or connect Vercel GitHub App for automatic deploys.
2. For Firebase/GCP (optional):
   - Create service account `github-action-1141712509@sandhere-web.iam.gserviceaccount.com` in GCP project `sandhere-web`.
   - Download JSON key, base64 encode, add as `FIREBASE_SERVICE_ACCOUNT_SANDHERE_WEB` secret.
   - Uncomment Firebase job.
3. Commit & push to `main`: `git add .github && git commit -m "Add GitHub Actions CI/CD" && git push`.
4. Verify workflow runs in GitHub Actions tab.

## Testing:
- Run `flutter pub get && flutter analyze && flutter test` locally.


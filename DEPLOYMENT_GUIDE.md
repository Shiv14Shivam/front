# SandHere Deployment Guide
## Best Approach: Backend First → Frontend

### Why Backend First?
Flutter frontend depends on Laravel API/WebSocket. Deploy backend → update `lib/config/app_config.dart` BACKEND_HOST → deploy frontend.

### 1. Backend (Laravel + PostgreSQL + Reverb) - Nixpacks Ready
```
cd ../Herd/sandbackend
composer install --no-dev --optimize-autoloader
cp .env.example .env
php artisan key:generate
# Set .env: DB_*, REVERB_APP_KEY, MAIL_*, RAZORPAY_KEY_SECRET (see requirements.txt)
php artisan migrate --force
php artisan reverb:start  # Verify WS
```
**Deploy Options** (5 mins):
- **Railway/Render**: `git push` (auto Nixpacks)
- **Heroku**: `heroku create; git push heroku main`
- **Production**: Add Redis for Reverb scaling + queue workers

**Get URL**: https://sandhere-backend.up.railway.app

### 2. Update Frontend
Edit `lib/config/app_config.dart`:
```dart
const String BACKEND_HOST = 'https://sandhere-backend.up.railway.app';
```

### 3. Frontend (Flutter Multiplatform)
```
flutter pub get
```
- **Web**: `flutter build web` → Netlify/Vercel/Firebase Hosting
- **Android APK**: `flutter build apk --release`
- **iOS**: `flutter build ios --release` (Xcode)

### Verify
- Backend API: curl -X POST https://backend/api/login
- Frontend connects: flutter run -d chrome --dart-define=BACKEND_HOST=https://backend

## Production Scaling
- Backend: Supervisor (queue + reverb:start)
- Frontend: Environment vars for BACKEND_HOST
- Monitoring: Laravel Telescope/Pail (logs)

Ready for production!


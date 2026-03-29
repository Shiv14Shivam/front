# Fix Frontend-Backend Network Error

## Steps:
- [x] 1. Analyzed files: app_config.dart, api_service.dart, websocket_service.dart, session_manager.dart
- [x] 2. Updated lib/config/app_config.dart with proper host logic and dart-define support
- [x] 3. Verified websocket host extraction works (uses Uri.host from baseUrl → sandbackend.test)
- [x] 4. Instructions for running added to app_config.dart comments
- [x] 5. Updated backend CORS to allow sandbackend.test origins
- [x] 6. Check CORS if needed (backend config/cors.php) → done
- [x] 7. Added BACKEND_PORT dart-define (default 80 for Herd)
- [x] 8. Updated TODO.md
- [x] 9. Tested: login success ✅
- [x] 10. Task complete: Frontend now connects to Laravel Herd backend


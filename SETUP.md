# ⚡ Hướng dẫn cài đặt nhanh

## 1. Clone & chạy ngay

```bash
git clone https://github.com/YOUR_USERNAME/viet_calendar.git
cd viet_calendar
flutter pub get
flutter run
```

## 2. Đẩy lên GitHub & tự build

```bash
git init
git add .
git commit -m "feat: initial commit - Lịch Việt app"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/viet_calendar.git
git push -u origin main
```

GitHub Actions sẽ **tự động chạy** khi push:
- ✅ Code quality check
- ✅ Unit tests
- ✅ Build Android APK (debug)

## 3. Tạo Release (build APK release + tạo GitHub Release)

```bash
git tag v1.0.0
git push origin v1.0.0
```

## 4. Cấu hình Signed APK (tuỳ chọn)

### Tạo keystore
```bash
keytool -genkey -v \
  -keystore android/app/keystore.jks \
  -keyalg RSA -keysize 2048 \
  -validity 10000 \
  -alias viet_calendar \
  -dname "CN=Viet Calendar, OU=Mobile, O=Your Company, L=Hanoi, S=Hanoi, C=VN"
```

### Encode sang base64
```bash
# macOS / Linux
base64 -i android/app/keystore.jks > keystore.b64
cat keystore.b64

# Windows PowerShell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("android\app\keystore.jks"))
```

### Thêm vào GitHub Secrets
Vào: `Repository Settings → Secrets and variables → Actions → New repository secret`

| Secret Name | Giá trị |
|------------|---------|
| `KEYSTORE_BASE64` | Nội dung file keystore.b64 |
| `KEYSTORE_PASSWORD` | Mật khẩu keystore bạn đặt |
| `KEY_ALIAS` | `viet_calendar` |
| `KEY_PASSWORD` | Mật khẩu key bạn đặt |

## 5. Codecov (coverage report, tuỳ chọn)

1. Vào [codecov.io](https://codecov.io) → đăng nhập GitHub → thêm repo
2. Copy token → thêm vào GitHub Secrets: `CODECOV_TOKEN`

## 6. Cấu trúc Notification Channels (Android)

| Channel ID | Tên | Dùng cho |
|-----------|-----|---------|
| `event_channel` | Nhắc nhở sự kiện | Sự kiện cá nhân (Priority: HIGH) |
| `holiday_channel` | Ngày lễ & Sự kiện đặc biệt | Ngày lễ VN (Priority: DEFAULT) |

## 7. Test thông báo

Trong app → Tab **Cài đặt** → **Test thông báo** → Thông báo xuất hiện ngay.

## 8. Permissions Android cần cấp

| Permission | Mục đích |
|-----------|---------|
| `POST_NOTIFICATIONS` | Android 13+ - bắt buộc để gửi thông báo |
| `SCHEDULE_EXACT_ALARM` | Android 12+ - thông báo đúng giờ |
| `RECEIVE_BOOT_COMPLETED` | Khôi phục thông báo sau restart |

---

## Workflow CI/CD chi tiết

```
Push to any branch
    ↓
┌─────────────────────────────┐
│  Job 1: Code Quality        │
│  - flutter analyze          │
│  - dart format check        │
└─────────────────────────────┘
    ↓
┌─────────────────────────────┐
│  Job 2: Tests               │
│  - flutter test --coverage  │
│  - Upload to Codecov        │
└─────────────────────────────┘
    ↓
┌─────────────────────────────┐
│  Job 3: Android Debug APK   │
│  - flutter build apk --debug│
│  - Upload artifact          │
└─────────────────────────────┘

Push to main / Tag v*.*.*:
    ↓
┌─────────────────────────────┐   ┌─────────────────────────────┐
│  Job 4: Android Release     │   │  Job 5: iOS Build           │
│  - flutter build apk        │   │  - pod install              │
│  - flutter build appbundle  │   │  - flutter build ios        │
│  - Upload artifacts         │   │  - Upload .app              │
└─────────────────────────────┘   └─────────────────────────────┘

Tag v*.*.* only:
    ↓
┌─────────────────────────────┐
│  Job 6: GitHub Release      │
│  - Auto changelog           │
│  - Attach APK + AAB         │
│  - Publish release          │
└─────────────────────────────┘
```

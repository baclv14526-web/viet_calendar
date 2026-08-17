# 🗓️ Lịch Việt - Vietnamese Calendar App

[![Flutter CI/CD](https://github.com/your-username/viet_calendar/actions/workflows/flutter_ci.yml/badge.svg)](https://github.com/your-username/viet_calendar/actions/workflows/flutter_ci.yml)
[![Flutter Version](https://img.shields.io/badge/Flutter-3.22.2-blue.svg)](https://flutter.dev)
[![Dart Version](https://img.shields.io/badge/Dart-3.3.0-blue.svg)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Ứng dụng lịch Dương lịch & Âm lịch Việt Nam với đầy đủ tính năng: ngày lễ truyền thống, thông báo sự kiện như Google Calendar.

---

## ✨ Tính năng

### 📅 Lịch
- **Dương lịch & Âm lịch** hiển thị song song trên mỗi ô ngày
- **Chế độ xem Tháng / Tuần** dễ dàng chuyển đổi
- Hiển thị **pha mặt trăng** theo ngày âm lịch (🌑🌒🌕🌘)
- Tên năm âm lịch đầy đủ: Thiên Can + Địa Chi (Giáp Thìn, Ất Tỵ...)

### 🏮 Ngày lễ Việt Nam (tự động)

#### Dương lịch
| Ngày | Tên |
|------|-----|
| 1/1  | 🎆 Tết Dương Lịch |
| 3/2  | 🔴 Ngày thành lập Đảng CSVN |
| 8/3  | 🌹 Ngày Quốc tế Phụ nữ |
| 30/4 | 🏳️ Ngày Giải phóng Miền Nam |
| 1/5  | ⚙️ Ngày Quốc tế Lao động |
| 2/9  | 🇻🇳 Quốc khánh Việt Nam |
| 20/10 | 🌸 Ngày Phụ nữ Việt Nam |
| 20/11 | 📚 Ngày Nhà giáo Việt Nam |
| 22/12 | ⭐ Ngày Quân đội Nhân dân |
| 25/12 | 🎄 Giáng Sinh |

#### Âm lịch (tự động tính theo năm)
| Ngày âm | Tên |
|---------|-----|
| 30 tháng Chạp | 🎊 Giao Thừa |
| 1/1 | 🧧 Tết Nguyên Đán |
| 2/1, 3/1 | 🎉 Mùng 2, Mùng 3 Tết |
| 10/1 | 💰 Ngày Thần Tài |
| 15/1 | 🏮 Tết Nguyên Tiêu / Rằm tháng Giêng |
| 10/3 | 👑 Giỗ Tổ Hùng Vương |
| 5/5 | 🍚 Tết Đoan Ngọ |
| 15/7 | 🙏 Lễ Vu Lan / Rằm tháng 7 |
| 15/8 | 🌕 Tết Trung Thu |
| 23/12 | 🔥 Ông Táo Về Trời |

### 🔔 Thông báo (như Google Calendar)
- Thông báo **popup** đầy đủ màn hình cho sự kiện quan trọng
- **Notification channel** riêng cho sự kiện và ngày lễ
- Tùy chọn nhắc trước: 5p, 10p, 15p, 30p, 1h, 2h, 1 ngày
- Khôi phục thông báo sau khi **restart máy** (BOOT_COMPLETED)
- Hỗ trợ **Android 12+ exact alarms**

### 📋 Quản lý sự kiện
- Thêm / Sửa / Xóa sự kiện cá nhân
- Swipe to delete / edit (flutter_slidable)
- Màu sắc sự kiện tùy chỉnh (10 màu)
- Lặp lại: ngày / tuần / tháng / năm
- Lưu trữ offline với **SQLite**

### 🎨 UI/UX
- Material Design 3 (Material You)
- Dark Mode tự động theo hệ thống
- Font **Noto Sans** hỗ trợ tiếng Việt đầy đủ
- Animation mượt mà (flutter_staggered_animations)
- Bottom Navigation Bar với 4 tab

---

## 🚀 Quick Start

### Yêu cầu
- Flutter **3.22+** (stable)
- Dart **3.3+**
- Android SDK 21+ / iOS 12+
- Java 17+

### Cài đặt

```bash
# Clone repository
git clone https://github.com/your-username/viet_calendar.git
cd viet_calendar

# Cài dependencies
flutter pub get

# Chạy app
flutter run
```

### Build APK

```bash
# Debug
flutter build apk --debug

# Release
flutter build apk --release

# App Bundle (Google Play)
flutter build appbundle --release
```

---

## 🏗️ Kiến trúc

```
lib/
├── main.dart                    # Entry point, theme setup
├── models/
│   ├── calendar_event.dart     # Data model cho sự kiện
│   └── lunar_date.dart         # Data model cho ngày âm lịch
├── services/
│   ├── calendar_bloc.dart      # BLoC state management
│   ├── database_service.dart   # SQLite CRUD
│   └── notification_service.dart # Local notifications
├── utils/
│   ├── lunar_converter.dart    # Thuật toán đổi dương↔âm lịch
│   └── vietnamese_holidays.dart # Database ngày lễ VN
├── screens/
│   ├── home_screen.dart        # Bottom navigation
│   ├── calendar_screen.dart    # Màn hình lịch chính
│   ├── add_event_screen.dart   # Thêm/sửa sự kiện
│   ├── agenda_screen.dart      # Danh sách sự kiện sắp tới
│   ├── holidays_screen.dart    # Danh sách ngày lễ
│   └── settings_screen.dart   # Cài đặt
└── widgets/
    ├── event_card.dart         # Card hiển thị sự kiện
    └── lunar_info_widget.dart  # Widget thông tin âm lịch
```

### State Management: BLoC Pattern
```
UI → Event → CalendarBloc → State → UI rebuild
```

### Database: SQLite (sqflite)
- Bảng `events`: Lưu sự kiện cá nhân
- Ngày lễ được tính toán realtime, không lưu DB

---

## 🤖 CI/CD - GitHub Actions

### Workflow tự động khi push

| Trigger | Jobs chạy |
|---------|-----------|
| Push bất kỳ branch | Code Quality + Tests + Android Debug |
| Push `main` | + Android Release + iOS |
| Tag `v*.*.*` | + GitHub Release tự động |
| Pull Request | Code Quality + Tests |

### Cách tạo Release

```bash
# Tag và push để tự động build + release
git tag v1.0.0
git push origin v1.0.0
```

### Cấu hình Secrets (cho signed APK)

Vào **GitHub Settings → Secrets → Actions**, thêm:

| Secret | Mô tả |
|--------|-------|
| `KEYSTORE_BASE64` | `base64 -i keystore.jks` |
| `KEYSTORE_PASSWORD` | Mật khẩu keystore |
| `KEY_ALIAS` | Alias key |
| `KEY_PASSWORD` | Mật khẩu key |

### Tạo Keystore

```bash
keytool -genkey -v \
  -keystore android/app/keystore.jks \
  -keyalg RSA -keysize 2048 \
  -validity 10000 \
  -alias viet_calendar

# Encode sang base64
base64 -i android/app/keystore.jks | pbcopy
```

---

## 📦 Thư viện chính

| Package | Phiên bản | Mục đích |
|---------|-----------|---------|
| `flutter_bloc` | 8.1.6 | State management |
| `table_calendar` | 3.1.2 | Widget lịch |
| `flutter_local_notifications` | 17.2.4 | Thông báo |
| `timezone` | 0.9.4 | Múi giờ GMT+7 |
| `sqflite` | 2.3.3 | Cơ sở dữ liệu |
| `shared_preferences` | 2.3.2 | Settings |
| `google_fonts` | 6.2.1 | Font Noto Sans |
| `intl` | 0.19.0 | Định dạng ngày/giờ |
| `flutter_slidable` | 3.1.1 | Swipe actions |
| `permission_handler` | 11.3.1 | Quản lý quyền |
| `animations` | 2.0.11 | Hiệu ứng chuyển trang |
| `uuid` | 4.4.2 | Tạo ID duy nhất |

---

## 🧮 Thuật toán Âm lịch

Thuật toán chuyển đổi Dương↔Âm lịch dựa trên:
- Múi giờ **GMT+7** (Việt Nam)
- Tính ngày **sóc (New Moon)** theo công thức thiên văn
- Xác định **tháng nhuận** dựa trên kinh độ mặt trời
- Thuật toán gốc của **Hồ Ngọc Đức** (Ho Ngoc Duc)
- Chính xác từ năm **1900 đến 2100**

---

## 🧪 Tests

```bash
# Chạy tất cả tests
flutter test

# Với coverage
flutter test --coverage

# Xem báo cáo coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Test coverage
- `lunar_converter_test.dart` - Kiểm tra chuyển đổi âm/dương lịch
- `holidays_test.dart` - Kiểm tra đủ ngày lễ VN
- `calendar_event_test.dart` - Kiểm tra model serialization

---

## 📱 Screenshots

> Thêm screenshots sau khi build xong

---

## 📄 License

MIT License - xem file [LICENSE](LICENSE)

---

## 🤝 Đóng góp

1. Fork repository
2. Tạo branch: `git checkout -b feature/ten-tinh-nang`
3. Commit: `git commit -m 'Add: thêm tính năng XYZ'`
4. Push: `git push origin feature/ten-tinh-nang`
5. Tạo Pull Request

---

*Made with ❤️ for Vietnam 🇻🇳*

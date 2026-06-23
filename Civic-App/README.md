# CityPulse (Smart-City) — Citizen Issue Portal 🏙️

A **production-quality Flutter frontend** for reporting and tracking city issues (potholes, streetlights, water leaks, garbage, power outages, and more). Designed with a clean civic-tech aesthetic using Material 3 with **overflow-free responsive design** and **Instagram-style swipe navigation**.

---

## 🚀 How to Run

```bash
cd Smart-City

# Install dependencies
flutter pub get

# Run on a device/emulator
flutter run

# Build for release
flutter build apk --release   # Android
flutter build ipa              # iOS
```

**Minimum SDK:** Flutter 3.24+, Dart 3.5+

---

## 👤 How to Switch Roles

On the **Auth Screen**, use one of two quick-login buttons:

| Button | Role | Home Destination |
|---|---|---|
| **Login as Citizen** | Citizen | `/citizen/home` |
| **Login as Admin** | Admin | `/admin/dashboard` |

You can also toggle between roles by logging out (Settings → Logout) and logging in again with a different role.

---

## 📱 App Screens

### Common
- **SplashScreen** — Logo animation → auto-navigate
- **OnboardingScreen** — 3 slides (Skip / Get Started)
- **AuthScreen** — Email/password + role quick-login + Forgot Password
- **GlobalSearchScreen** — Debounced search across all issues
- **SettingsScreen** — Theme toggle (System/Light/Dark), version, logout, debug storage

### Citizen Module (Bottom Nav)
- **Home** — Greeting, search bar, category chips, nearby & recent issues, skeleton loading, pull-to-refresh
- **Report Issue** — 4-step stepper (Category → Details → Location → Photos) + success sheet
- **My Issues** — Status filter chips + sort + my reported issues
- **Issue Details** — Hero animation from card, status timeline, attachments, share, **swipe-to-go-back**
- **Notifications** — Mock notification list with read/unread states

### Admin Module (Bottom Nav / Adaptive Drawer on tablet)
- **Dashboard** — **Responsive KPI cards** (Total/Open/In Progress/Resolved), quick actions, critical ward areas, urgent issues
- **Issues** — **Optimized search** + **compact filters** + sort + issue list
- **Issue Details** — Reporter info, status update dropdown, internal notes, save → timeline updates, **swipe-to-go-back**
- **Analytics** — fl_chart line chart (14-day trend), bar charts by category and ward
- **Map View** — Stylized grid canvas with colored issue pins, filter chips, tap-to-preview sheet

---

## 🎯 Recent Improvements

### ✅ **Overflow-Free Design**
- **Fixed all horizontal/vertical overflow issues** across all screen sizes
- **Responsive KPI cards** that adapt to screen height
- **Optimized TextFields and Dropdowns** with proper padding and font sizing
- **Compact input layouts** that prevent rendering errors

### ✅ **Instagram-Style Swipe Navigation**
- **Smart swipe detection** - only works when there's a previous route
- **No accidental app exit** - disabled on home/dashboard screens
- **Enabled on detail screens** - swipe back to previous list
- **Custom page transitions** with smooth animations

### ✅ **Enhanced UI/UX**
- **Improved skeleton loaders** matching actual content dimensions
- **Better text overflow handling** with ellipsis
- **Optimized spacing and sizing** for mobile devices
- **Consistent visual hierarchy** throughout the app

---

## 🗂️ Folder Structure

```
lib/
├── core/
│   ├── constants/       ← spacing, radii, durations, keys
│   ├── routing/         ← go_router with Instagram-style transitions
│   ├── theme/           ← Material 3 light/dark themes, ThemeController
│   └── widgets/         ← IssueCard, StatusPill, CategoryChip, EmptyState,
│                          SkeletonLoader, TimelineStepper, SwipeNavigationWrapper
├── features/
│   ├── auth/            ← models, controllers, screens (Splash, Onboarding, Auth)
│   ├── citizen/         ← CitizenShell + 5 screens
│   ├── admin/           ← AdminShell + 5 screens
│   ├── common/          ← GlobalSearch, Settings, DebugStorage
│   └── issues/          ← models, repositories, providers
└── main.dart
```

---

## 🔌 Connecting to a Real Backend Later

All data access flows through `IssueRepository` in:
```
lib/features/issues/repositories/issue_repository.dart
```

To connect a real API:
1. Create `RemoteIssueRepository` implementing the same methods
2. Replace `issueRepositoryProvider` in `lib/features/issues/providers/issue_providers.dart` to return the remote implementation
3. No screen or widget code needs to change

Similarly, `AuthController` in `lib/features/auth/controllers/auth_controller.dart` can be swapped for a real auth provider (Firebase Auth, OAuth, etc.) by updating only the `loginAsCitizen` / `loginAsAdmin` methods.

---

## 🎨 Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (Material 3) |
| State Management | Riverpod 2 (StateNotifier) |
| Navigation | go_router (guarded routes + custom transitions) |
| Charts | fl_chart |
| Skeleton Loading | shimmer |
| Typography | Google Fonts (Outfit) |
| Persistence | shared_preferences |
| ID Generation | uuid |
| Page Transitions | page_transition |
| Swipe Gestures | GestureDetector + PopScope |

---

## 🛠️ Mock Data

- **20 seeded issues** across 7 categories, 10 wards, 5 reporters, and all 4 statuses
- Status history is auto-seeded per issue
- Pull-to-refresh triggers an 800ms mock delay
- Report Issue adds the new issue to the in-memory repository instantly
- Admin status updates immediately reflect in the timeline
- **User accounts stored locally** with SHA-256 password hashing

---

## 🔧 Development Features

- **Debug Storage Screen** - View all SharedPreferences data
- **Responsive Design** - Adapts to all screen sizes without overflow
- **Instagram-Style Navigation** - Intuitive swipe gestures
- **Error-Free Rendering** - No layout overflow issues
- **Performance Optimized** - Efficient widget usage and state management

---

*Built with ❤️ for better cities.*

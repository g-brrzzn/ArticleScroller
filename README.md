# Article Scroller

**A clean and fluid platform for discovering and reading scientific papers from arXiv.**

Built with **Flutter**, Article Scroller runs smoothly on **Android** and **Windows** from a single codebase. It focuses on simplicity, fast navigation, and an enjoyable reading experience — all without a backend.

The app fetches papers directly from the arXiv API, converts LaTeX/PDF content into clean Markdown using ar5iv, and stores everything locally with SQLite for true offline access and fast performance.

---

## 📱 Demo

<p align="center">
  <img src="https://github.com/user-attachments/assets/2a159ec4-f712-418e-8dc0-0740d492b15e" alt="Feed View" width="45%">
  <img src="https://github.com/user-attachments/assets/6b6a7b40-7201-4933-ad38-4cb0f7703bbe" alt="Article View" width="45%">
</p>

---

## 🧠 Overview
Article Scroller is a lightweight, client-side application that makes exploring arXiv papers simple and pleasant. By handling everything directly on the device — from API communication to content rendering and storage — it delivers a responsive experience with full offline support.

---

## 🚀 Features

- **Trending Research Feed**  
  Aggregates relevant papers across domains (AI, CS, Biology, etc.) based on recency and signal relevance.

- **Full-Text Extraction**  
  Integrates with Ar5iv to convert LaTeX/PDF papers into clean, readable Markdown.

- **Offline-First Storage**  
  Uses a local SQLite database to persist articles, bookmarks, and history.

- **Cross-Platform**  
  Runs on Android and Windows using a unified Flutter codebase.

- **Advanced Search**  
  Filter papers by category, timeframe, or custom queries.

---

## 🧱 Tech Stack

- **Framework**: Flutter (Dart)
- **Database**: SQLite (`sqflite`, `sqflite_common_ffi`)
- **Rendering**: `flutter_markdown`
- **Networking**: `http` (custom headers for arXiv API compliance)
- **Parsing**:
  - `xml` → arXiv API responses  
  - `html` → Ar5iv content extraction  

---

## 📂 Directory Structure and Architecture

```text
article-scroller/
├── assets/                 # Branding and icons
├── lib/
│   ├── screens/            # UI screens (Feed, Discover, Library)
│   ├── services/           # Business logic and data layer
│   └── main.dart
├── android/                # Android configuration
├── windows/                # Windows desktop runner
├── docs/                   # Screenshots and demos
└── pubspec.yaml
```

The project follows a **service-oriented architecture** with clear separation of concerns:

- `arxiv_service.dart`  
  Handles API communication, XML parsing, and Ar5iv scraping.

- `database_service.dart`  
  Manages SQLite lifecycle, schema, and CRUD operations.

- `screens/`  
  UI layer optimized with `IndexedStack` and `PageView` for smooth navigation.


## ⚙️ Setup & Installation

> 📦
> Prebuilt versions are available — no setup required.  
> You can download the latest release for Windows and Android (APK) here:  
> https://github.com/g-brrzzn/ArticleScroller/releases

---

### Manual building

Clone the repository:

```bash
# Clone the repository
git clone https://github.com/g-brrzzn/ArticleScroller.git

# Navigate to the project
cd article-scroller

# Install dependencies
flutter pub get

# Generate launcher icons (optional)
dart run flutter_launcher_icons

# Run the app
flutter run
```

### Prerequisites

- Flutter SDK (^3.11.4)
- Android Studio or VS Code
- C++ Build Tools (for Windows)

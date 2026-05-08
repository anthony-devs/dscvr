# DSCVR

> Your personal knowledge library and AI-powered research companion.

DSCVR is a modern research and study platform built for students, researchers, developers, and curious minds.  
Organize knowledge into Categories → Topics → Materials, read papers distraction-free, take notes, create canvases, and use Pinda AI to understand anything faster.

Built with Flutter for Web-first performance and scalability.

---

# ✨ Features

## 📚 Personal Knowledge Library
Organize everything you learn.

- Create Categories
- Create Topics inside categories
- Add PDFs, links, notes, YouTube videos, and canvases
- Save and bookmark materials
- Continue reading across devices

---

## 🔍 Discover Research
A built-in discovery system powered by external research APIs.

- Trending papers
- Subject-based feeds
- Public topics
- Semantic Scholar integration
- arXiv integration
- Wikipedia summaries

---

## 🤖 Pinda AI
An AI research assistant integrated across the entire platform.

### Pinda can:
- Summarize papers
- Explain difficult concepts
- Fact-check claims
- Generate study guides
- Quiz users
- Compare materials
- Analyze your library

### Context-aware AI
Pinda can work with:
- A single material
- A topic
- A full category
- General knowledge

---

## 📄 Readers
Distraction-free reading experience.

### PDF Reader
- Continuous scroll
- Highlights
- Notes
- Progress tracking
- Zoom support

### Link Reader
- Clean article rendering
- Readability mode
- AI-generated table of contents

### YouTube Reader
- Transcript support
- Searchable transcript
- AI summaries
- Timestamp navigation

---

## 📝 Notes
Rich note-taking system.

- Rich text editor
- Slash commands
- Markdown-style formatting
- Math/LaTeX support
- Embedded AI blocks
- Auto-save

---

## 🎨 Canvas
Infinite whiteboard for visual thinking.

- Shapes
- Arrows
- Text
- Image support
- AI nodes
- Material linking

---

## 🔗 Sharing & Collaboration
Share knowledge like Figma or GitHub.

- Share categories
- Share topics
- Share notes
- Share canvases
- Invite collaborators
- Fork public content

---

## 👤 Profiles
Public user profiles with discoverable knowledge collections.

- Public categories
- Public topics
- Follow users
- Share profiles

---

# 🏗 Architecture

## Tech Stack

### Frontend
- Flutter Web
- Dart
- Riverpod / BLoC
- GoRouter

### Backend
- Firebase or Supabase
- Cloud Storage
- Authentication
- Realtime Database

### APIs
- Semantic Scholar API
- arXiv API
- Wikipedia API
- YouTube Metadata APIs
- Claude API

---

# 📂 Project Structure

```txt
lib/
├── core/
├── shared/
├── services/
├── models/
├── router/
├── theme/
├── features/
│   ├── auth/
│   ├── onboarding/
│   ├── discover/
│   ├── library/
│   ├── topics/
│   ├── readers/
│   ├── notes/
│   ├── canvas/
│   ├── pinda/
│   ├── sharing/
│   ├── profile/
│   └── settings/
└── main.dart
```

---

# 🚀 Getting Started

## Prerequisites

- Flutter SDK
- Dart SDK
- Chrome
- Firebase/Supabase project
- Claude API key

---

# ⚙️ Installation

## Clone the repository

```bash
git clone https://github.com/yourusername/dscvr.git
cd dscvr
```

## Install dependencies

```bash
flutter pub get
```

## Run the app

```bash
flutter run -d chrome
```

---

# 🔑 Environment Variables

Create a `.env` file:

```env
CLAUDE_API_KEY=
SEMANTIC_SCHOLAR_API=
SUPABASE_URL=
SUPABASE_ANON_KEY=
YOUTUBE_API_KEY=
```

---

# 📱 Platforms

| Platform | Support |
|----------|----------|
| Web | ✅ Primary |
| Android | ✅ |
| iOS | ✅ |
| macOS | Planned |
| Windows | Planned |

---

# 🧠 Core Concepts

```txt
DSCVR
├── Discover
│   └── Public Topics
│
└── Your Library
    └── Categories
        └── Topics
            └── Materials
```

### Materials can be:
- PDFs
- Links
- Notes
- YouTube videos
- Canvases

---

# 🎯 MVP Goals

## Phase 1
- Authentication
- Discover
- Library system
- Topic management
- PDF reader
- Notes
- Basic Pinda AI

## Phase 2
- Sharing
- Public profiles
- YouTube reader
- Highlights and notes

## Phase 3
- Canvas
- Collaboration
- Advanced AI tools
- Realtime features

---

# 🎨 Design Philosophy

DSCVR is designed to feel:
- Minimal
- Calm
- Fast
- Academic
- Focused
- Human

No ads.  
No clutter.  
No algorithm addiction.

Just knowledge.

---

# 🔒 Privacy

- Private by default
- User-controlled sharing
- AI only reads provided context
- No selling user data

---

# 💡 Inspiration

Inspired by:
- Research tools
- Knowledge systems
- Academic workflows
- Modern collaborative software
- Deep study environments

---

# 🤝 Contributing

Contributions, ideas, and feedback are welcome.

## Areas needing work:
- Performance optimization
- Canvas engine
- Rich text editor
- AI tooling
- Accessibility
- Offline sync

---

# 📌 Status

🚧 Currently in active development.

Web-first Flutter implementation is the primary focus.

---

# 📜 License

MIT License

---

# ❤️ Philosophy

DSCVR is being built to help people learn better, study deeper, and organize knowledge without noise.

Free forever.  
Supported by donations only.

---

# 👨‍💻 Author

Built by Anthony.

For every student.
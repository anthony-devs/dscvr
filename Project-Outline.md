# DSCVR — Flutter Web Project Outline

> Main focus: Flutter Web first  
> Stack idea: Flutter + Riverpod/BLoC + GoRouter + Firebase/Supabase + REST APIs

---

# 1. Project Foundation

## Core Setup
- Flutter Web setup
- Routing/navigation system
- Theme system (light/dark/system)
- Responsive layout engine
- State management
- API service layer
- Local cache/storage
- Authentication setup
- Environment config
- Error handling system
- Analytics/logging

## App Architecture
- Feature-first folder structure
- Reusable component library
- Shared models
- Shared services
- Shared utilities
- Constants/design tokens

---

# 2. Authentication & Onboarding

## Auth Features
- Sign up
- Login
- Logout
- Forgot password
- Session persistence
- Guest mode

## Onboarding Screens
- Username setup
- Handle validation
- Privacy screen
- Interest selection
- Ready screen

## User Setup Logic
- Save selected interests
- Create default library
- Create user profile
- Load starter Discover feed

---

# 3. Navigation System

## Web Navigation
- Top navigation bar
- Sidebar navigation
- Bottom mobile nav
- Breadcrumbs
- Search navigation
- Nested routes

## Route Structure
- `/discover`
- `/library`
- `/category/:id`
- `/topic/:id`
- `/reader/:id`
- `/pinda`
- `/profile/:username`
- `/settings`
- `/shared/:id`

---

# 4. Design System

## UI Foundation
- Typography system
- Color system
- Shadows
- Spacing scale
- Border radius system
- Animation presets

## Reusable Components
- Buttons
- Chips
- Cards
- Inputs
- Dropdowns
- Modals
- Bottom sheets
- Toasts
- Tabs
- Toolbars
- Menus
- Skeleton loaders
- Empty states

---

# 5. Discover Module

## Discover Home
- Trending topics
- Featured papers
- Subject sections
- Search bar
- Search results
- Guest prompts

## Topic Page
- Topic banner
- Topic info
- Follow system
- Papers list
- Topic sorting
- Related topics
- Wikipedia summary
- Share topic

## Search System
- Search papers
- Search topics
- Search users
- Unified search dropdown
- Search results page

## API Integrations
- Semantic Scholar API
- arXiv API
- Wikipedia API

---

# 6. Library Module

## Library Home
- Greeting section
- Continue reading
- Categories grid
- Recently added
- Saved items

## Categories
- Create category
- Edit category
- Delete category
- Share category
- Invite collaborators
- Category privacy

## Topics
- Create topic
- Edit topic
- Delete topic
- Public/private topics
- Topic sorting
- Topic sharing

## Materials
- Material listing
- Material sorting
- Material filtering
- Material actions menu

---

# 7. Add Material System

## PDF Upload
- Upload PDF
- Parse PDF
- Store metadata
- Generate preview
- Extract text

## Link Import
- URL validation
- Metadata scraping
- OG image fetching
- Link preview generation

## Notes
- Create note
- Rich text editor
- Markdown/formatting
- Auto-save

## YouTube Integration
- Parse YouTube links
- Fetch thumbnail
- Fetch metadata
- Fetch transcript

## Canvas Creation
- Create canvas
- Open canvas editor

---

# 8. Reader System

## PDF Reader
- PDF rendering
- Continuous scrolling
- Zoom controls
- Progress tracking
- Page tracking

## Article Reader
- Readability layout
- Content rendering
- Scroll tracking
- Progress saving

## Reader Toolbar
- Table of contents
- Highlights panel
- Notes panel
- Share actions
- Bookmarking

## Highlight System
- Text selection
- Highlight colors
- Save highlights
- Highlight navigation
- Delete highlights

## Notes System
- Anchored notes
- General notes
- Inline note creation
- Notes navigation

---

# 9. YouTube Reader

## Video Experience
- Embedded player
- Playback controls
- Speed control
- Fullscreen support

## Transcript System
- Transcript fetching
- Auto-scroll
- Transcript search
- Timestamp navigation
- Highlight transcript text

## Chapters
- Detect chapters
- Generate AI chapters
- Chapter navigation

---

# 10. Note Editor

## Rich Text Editing
- Formatting toolbar
- Headers
- Lists
- Code blocks
- Inline code
- Math/LaTeX
- Links
- Images

## Editor Features
- Auto-save
- Slash commands
- Keyboard shortcuts
- Offline drafts

## Export Features
- Export markdown
- Export PDF

---

# 11. Canvas System (Web Priority)

## Canvas Engine
- Infinite canvas
- Zoom/pan
- Grid background
- Drag/drop support

## Drawing Tools
- Selection tool
- Rectangle
- Circle
- Arrow/line
- Text tool
- Image tool
- Eraser

## Canvas Objects
- Resizing
- Rotation
- Connections
- Layering

## Material Integration
- Drag materials onto canvas
- Linked material cards
- Open material in side panel

## Pinda Nodes
- AI node generation
- Editable AI responses
- Connect nodes

---

# 12. Pinda AI Module

## AI Chat System
- Chat interface
- Streaming responses
- Conversation history
- Context switching

## Context System
- Material context
- Topic context
- Category context
- General context

## AI Features
- Summaries
- Fact checking
- Study guides
- Explanations
- Quizzes
- Recommendations

## Claude Integration
- Prompt system
- Context injection
- Token handling
- Rate limiting

---

# 13. Sharing & Collaboration

## Sharing System
- Generate share links
- Public/private sharing
- Copy link
- Permission settings

## Collaboration
- Invite users
- Role management
- Collaborator permissions

## Shared View
- Read-only reader
- Public comments
- Fork system
- Add-to-library flow

---

# 14. Comments System

## Comment Features
- Add comments
- Replies
- Upvotes
- Threaded discussions
- Comment deletion/reporting

---

# 15. Profile Module

## Public Profiles
- User profile page
- Public categories
- Public topics
- Follow users

## Profile Editing
- Avatar upload
- Bio editing
- Handle editing

---

# 16. Settings Module

## Appearance
- Theme switching
- Reader themes
- Font preferences

## Privacy
- Profile visibility
- Sharing defaults
- Blocked users

## Pinda Settings
- Response style
- Conversation saving
- Default context

## Library Settings
- Import/export
- Storage usage

## Account Settings
- Change email
- Change password
- Delete account

---

# 17. Backend Features

## Database
- Users
- Categories
- Topics
- Materials
- Notes
- Highlights
- Comments
- Conversations
- Shares

## Storage
- PDFs
- Images
- Avatars
- Canvas data

## Realtime
- Live collaboration
- Comments updates
- AI streaming

---

# 18. Offline & Sync

## Offline Features
- Cached materials
- Offline notes
- Draft saving
- Queue sync actions

## Sync System
- Conflict resolution
- Background sync
- Reconnect handling

---

# 19. Performance & Optimization

## Performance
- Lazy loading
- Pagination
- Virtualized lists
- Image optimization
- API caching

## Web Optimization
- SEO basics
- Fast initial load
- Code splitting
- Responsive layouts

---

# 20. Notifications

## Notifications
- Share invites
- Comments
- Follows
- Collaboration updates

---

# 21. Security

## Security Features
- Auth guards
- Permission validation
- File validation
- API protection
- Rate limiting

---

# 22. Deployment

## Deployment
- CI/CD
- Environment configs
- Domain setup
- Hosting
- Error monitoring

---

# 23. MVP Priority Order

## Phase 1 — Core MVP
- Auth
- Onboarding
- Discover
- Library
- Categories
- Topics
- Add Material
- PDF Reader
- Link Reader
- Notes
- Basic Pinda AI

## Phase 2
- Sharing
- Public profiles
- YouTube reader
- Highlights/notes system
- Search system

## Phase 3
- Canvas
- Collaboration
- Advanced AI
- Fact checking
- Realtime features

## Phase 4
- Offline sync
- Advanced exports
- Full optimization
- Analytics
- Notifications

---

# Suggested Flutter Folder Structure

```txt
lib/
├── core/
├── shared/
├── services/
├── models/
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
├── router/
├── theme/
└── main.dart
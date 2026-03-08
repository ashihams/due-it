# Due-It

An AI-powered task planning and productivity app built with Flutter.

## Features

- 🤖 **AI-Powered Planning**: Uses Gemini AI to break down tasks into daily subtasks
- 📅 **Adaptive Scheduling**: Automatically replans tasks daily based on completion status
- 📊 **Dashboard Analytics**: Track pressure scores, risk levels, and weekly goals
- 🔄 **Dynamic Replanning**: Tasks automatically adjust when work is missed
- 👤 **User-Specific Data**: Each user has their own isolated workspace

## Tech Stack

- **Frontend**: Flutter (Dart)
- **Backend**: FastAPI (Python) - [Separate Repository](https://github.com/ashihams/due-it-backend)
- **Database**: Firebase Firestore
- **Authentication**: Firebase Auth
- **AI**: Google Gemini API

## Project Structure

```
lib/
├── models/          # Data models (Task, DueTask, AIPlanningData)
├── providers/       # State management (TaskProvider)
├── screens/         # UI screens (Home, Dashboard, Calendar, Profile)
├── services/        # Business logic (TaskService, AIPlanningService)
├── theme/          # App theming
└── widgets/        # Reusable widgets
```

## Getting Started

### Prerequisites

- Flutter SDK (latest stable version)
- Firebase project setup
- Google Gemini API key

### Installation

1. Clone the repository:
```bash
git clone https://github.com/ashihams/due-it.git
cd due-it
```

2. Install dependencies:
```bash
flutter pub get
```

3. Configure Firebase:
   - Add your `google-services.json` to `android/app/`
   - Configure Firebase for iOS if needed

4. Run the app:
```bash
flutter run
```

## Key Features

### AI Task Decomposition
Tasks are automatically broken down into 10-30 minute subtasks with clear titles and actionable abstracts.

### Daily Replanning
The system automatically replans every day:
- Detects unfinished subtasks
- Redistributes remaining work across available days
- Updates pressure and risk scores dynamically

### User Data Isolation
All data is scoped per user using Firebase UID:
- `users/{uid}/tasks/{taskId}`
- Each user sees only their own tasks and plans

## License

This project is private and proprietary.

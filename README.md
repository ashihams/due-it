# DueIt


AI-powered task planning system with:
- Flutter frontend app (`due_it/`)
- FastAPI backend (`due_it_backend/`)
- Firebase Auth + Firestore
- Gemini-based planning
- Notion + TinyFish integrations for docs/resources/workflow automation

## Repository Layout

```text
.
├─ due_it/                 # Flutter frontend
│  ├─ lib/
│  ├─ android/ ios/ web/ ...
│  └─ pubspec.yaml
├─ due_it_backend/         # FastAPI backend
│  ├─ main.py
│  ├─ notion_service.py
│  ├─ tinyfish_service.py
│  ├─ requirements.txt
│  └─ Dockerfile
└─ README.md               # This file
```

## What DueIt Does

1. User signs in with Firebase Auth.
2. User creates a task in Firestore (`users/{uid}/tasks/{taskId}`).
3. Frontend calls backend `/plan-task`.
4. Backend uses Gemini to generate:
   - estimated duration
   - day-wise schedule
   - microtasks
   - pressure/risk metrics
5. Backend stores AI plan in Firestore.
6. Backend syncs task + launchpad docs to Notion (if connected).
7. Backend uses TinyFish to:
   - scrape useful resources
   - generate Excalidraw workflow links
8. Frontend reflects updates from Firestore in real time.

## Tech Stack

- Frontend: Flutter (Dart), Provider, Firebase SDK
- Backend: FastAPI (Python), Firebase Admin SDK, Requests
- Database: Firebase Firestore
- Auth: Firebase Authentication
- AI: Google Gemini
- Productivity integrations: Notion API, TinyFish automation API
- Deployment:
  - Frontend web: Vercel (config present)
  - Backend: Cloud Run (Dockerfile + cloudbuild config)

## Prerequisites

### Frontend
- Flutter SDK (stable)
- Firebase project configured for Android/iOS/Web as needed

### Backend
- Python 3.10+ recommended
- Firebase service account credentials for Admin SDK
- API keys/tokens:
  - Gemini API key
  - TinyFish API key
  - Notion OAuth client credentials

## Environment Configuration

Backend uses environment variables. Typical required values:

- `GOOGLE_API_KEY` (Gemini)
- `TINYFISH_API_KEY`
- `NOTION_OAUTH_CLIENT_ID`
- `NOTION_OAUTH_CLIENT_SECRET`
- `NOTION_REDIRECT_URI`
- `NOTION_PARENT_PAGE_ID` (optional fallback parent)
- `NOTION_DATABASE_ID` (optional bootstrap/fallback)
- Firebase Admin credentials (usually via `GOOGLE_APPLICATION_CREDENTIALS`)

> Keep secrets out of git. Use deployment secret managers or local `.env` tooling.

## Local Development

## 1) Run Backend

```bash
cd due_it_backend
python -m venv .venv
# Windows:
.venv\Scripts\activate
# macOS/Linux:
# source .venv/bin/activate

pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8080
```

Backend will be available at `http://localhost:8080`.

## 2) Point Frontend to Backend

Frontend service files currently use a deployed Cloud Run URL in code.  
For local full-stack testing, update frontend base URLs in:

- `due_it/lib/services/ai_planning_service.dart`
- `due_it/lib/services/notion_service.dart`

Change them to your local backend URL, for example:
- `http://10.0.2.2:8080` (Android emulator)
- `http://localhost:8080` (web/desktop)
- your machine IP for physical device testing.

## 3) Run Frontend

```bash
cd due_it
flutter pub get
flutter run
```

## Core Backend Endpoints

- `POST /health` - basic health check
- `POST /plan-task?taskId=...` - AI planning + Firestore update + optional Notion sync
- `POST /generate-doc` - create Notion launchpad and trigger TinyFish enrichment/workflow generation
- `POST /scrape-resources` - TinyFish resource scraping
- `GET /notion-auth-url?uid=...` - get Notion OAuth URL
- `GET /notion-callback` - Notion OAuth redirect handler
- `DELETE /disconnect-notion` - clear Notion token connection
- `POST /sync-task-complete?taskId=...` - update Notion task status
- `POST /create-excalidraw-workflow` - explicit workflow-generation trigger
- Testing utilities: `/test-tinyfish`, `/test-excalidraw`, `/test-excalidraw-task`, `/test-excalidraw-result/{job_id}`

## Firestore Data Model (Important)

User-level:
- `users/{uid}`
  - `notionToken`
  - `notionConnected`
  - `notionWorkspace`
  - `notionDatabaseId`
  - `notionParentPageId`

Task-level:
- `users/{uid}/tasks/{taskId}`
  - core fields: `title`, `description`, `dueDate`, `category`, `priority`, `completed`
  - AI fields: `ai.estimatedMinutes`, `ai.schedule`, `ai.pressureScore`, `ai.riskScore`, etc.
  - integration fields: `notionPageId`, `notionDocPageId`, `notionLaunchpadUrl`, `workflowUrl`
  - TinyFish fields: `tinyfishResources`, `resourcesScraped`

## Notion + TinyFish Workflow

1. User connects Notion via OAuth (`/notion-auth-url` -> `/notion-callback`).
2. `/plan-task` updates AI data and syncs task row to Notion DB.
3. `/generate-doc` creates category launchpad page with sections.
4. TinyFish scrapes resources and backend updates Notion resource section.
5. TinyFish generates Excalidraw workflow URL and backend patches Notion workflow placeholder.

## Deployment Notes

### Frontend (Vercel/Web)
- `due_it/vercel.json` and workflow files are present.
- Ensure production backend URL is set in frontend service files before deploy.

### Backend (Cloud Run)
- `due_it_backend/Dockerfile` and `cloudbuild.yaml` are available.
- Set all required env vars/secrets in the Cloud Run service.
- Ensure Firebase Admin permissions allow read/write to required Firestore paths.

## Troubleshooting

- Auth 401 on backend:
  - verify Firebase ID token is sent in `Authorization: Bearer ...`
  - ensure backend Firebase Admin is configured correctly

- Notion sync fails:
  - confirm OAuth token exists in `users/{uid}`
  - verify Notion integration has access to chosen parent page/database

- TinyFish failures:
  - check `TINYFISH_API_KEY`
  - inspect backend logs for raw TinyFish response parsing

- Flutter cannot reach local backend:
  - Android emulator uses `10.0.2.2`, not `localhost`
  - for real devices use LAN IP + open firewall port

## Contributing

1. Create a feature branch.
2. Keep frontend and backend changes scoped and documented.
3. Test:
   - frontend app flow
   - `/plan-task` + `/generate-doc`
   - Notion OAuth + task sync
4. Open a PR with test notes.

## License

MIT License (see `due_it/LICENSE`).


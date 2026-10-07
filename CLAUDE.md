# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AI medical consultation system (AI 医疗问诊系统) with four main components:
- **backend/** - FastAPI backend service (Python 3.11+)
- **frontend/** - React 19 user-facing web app (Vite + TypeScript + Tailwind CSS + Ant Design)
- **admin_web/** - React 18 admin dashboard (Vite + TypeScript + Tailwind CSS + Radix UI)
- **flutter_app/** - Flutter mobile app (Dart 3.11+)

## Common Commands

### Backend (FastAPI)

```bash
# Install dependencies
cd backend
pip install -r requirements.txt

# Run with Docker (includes PostgreSQL + Redis)
docker-compose up -d

# Run locally (requires PostgreSQL and Redis running)
python run.py

# Run with single worker (development)
uvicorn main:app --reload --host 0.0.0.0 --port 8000

# Database migrations
alembic upgrade head
alembic revision --autogenerate -m "description"

# Create admin user
python create-admin.py

# Reset admin password
python reset_admin_password.py
```

### Frontend (User App)

```bash
cd frontend
npm install
npm run dev          # Start dev server (port 5174 via nginx)
npm run build        # Build for production
npm run lint         # Run ESLint
npm run preview      # Preview production build
```

### Admin Web

```bash
cd admin_web
npm install
npm run dev          # Start dev server (port 5173 via nginx)
npm run build        # Build for production
npm run lint         # Run ESLint
npm run check        # TypeScript type check
```

### Flutter App

```bash
cd flutter_app
flutter pub get
flutter run          # Run on connected device
flutter build apk    # Build Android APK
flutter build ios    # Build iOS (requires macOS)
```

## Architecture Overview

### Backend Structure

```
backend/
├── main.py              # FastAPI app entry point, middleware, routes
├── agents.py            # LLM integration (DashScope/OpenAI compatible)
├── models.py            # SQLAlchemy ORM models
├── database.py          # Database connection, Redis client, init
├── memory.py            # LangChain chat memory (PostgreSQL-backed)
├── cache.py             # Two-level cache (L1: TTLCache, L2: Redis)
├── security.py          # JWT tokens, password hashing (bcrypt)
├── routers/             # API route handlers
│   ├── auth.py         # Authentication (login, SMS, carrier)
│   ├── profiles.py     # Patient profiles
│   ├── consultations.py # Medical consultation records
│   ├── chat_sessions.py # Chat session management
│   ├── admin.py        # Admin dashboard APIs
│   └── health.py       # Health check endpoint
├── middleware/          # Custom middleware (rate limiting)
└── migrations/          # Alembic database migrations
```

### Key Backend Patterns

**LLM Integration**: Uses OpenAI SDK with DashScope compatible API (`agents.py`)
- Two modes: `normal` (Q&A) and `medical` (multi-turn consultation)
- Streaming via SSE (Server-Sent Events)
- Medical mode outputs structured cards via `[CARD]...[/CARD]` tags

**Two-Level Cache** (`cache.py`):
- L1: Process-local TTLCache (maxsize=500, ttl=300s)
- L2: Redis shared cache (ttl=300s)
- Invalidation: `cache_invalidate()` / `cache_invalidate_pattern()`

**Authentication Flow**:
- JWT tokens (2h expiry) with bcrypt password hashing
- SMS verification via Aliyun Dypns API (code stored in Redis, 5min TTL)
- Carrier one-click login via Aliyun auth
- Token blacklist in Redis (7 day TTL)

**Data Encryption**: Patient sensitive fields (`medical_history`, `allergies`) encrypted with Fernet (AES-128-CBC)

### Frontend Architecture

**User App (frontend/)**: React 19 + Ant Design X
- Chat interface with SSE streaming
- Markdown rendering for medical responses
- Card components for structured consultation data

**Admin Dashboard (admin_web/)**: React 18 + Radix UI
- Zustand for state management
- Token stored in `localStorage` (key: `admin_token`)
- axios interceptor auto-attaches Authorization header
- 401/403 responses redirect to login

### Database Models

Core entities (see `backend/models.py`):
- `User` → `PatientProfile[]` → `ConsultationRecord[]`
- `User` → `ChatSession[]`
- `HighFreqQuestion` - Pre-defined Q&A templates
- `SystemConfig` - System settings
- `Agreement` - User agreement / privacy policy
- `AuditLog` - Admin action logs

### API Structure

- `/api/auth/*` - Authentication endpoints
- `/api/chat` - Main chat endpoint (SSE streaming)
- `/api/chat-sessions/*` - Session management
- `/api/profiles/*` - Patient profiles
- `/api/consultations/*` - Medical consultation records
- `/api/admin/*` - Admin dashboard APIs
- `/api/public/*` - Public endpoints (no auth required)

## Environment Configuration

Required env vars (see `backend/.env.example`):
- `DASHSCOPE_API_KEY` - Aliyun DashScope API key
- `SECRET_KEY` - JWT signing key
- `ENCRYPTION_KEY` - Fernet encryption key (patient data)
- `DATABASE_URL` - PostgreSQL connection string (asyncpg driver)
- `POSTGRES_PASSWORD` - Database password
- `REDIS_URL` - Redis connection (optional, falls back to fakeredis)

## Deployment

Docker Compose setup:
- `backend/docker-compose.yml` - Backend + PostgreSQL + Redis
- Root `docker-compose.yml` - Nginx serving both frontends
- Nginx config: `nginx.conf` (frontend on port 5174, admin on 5173)

## Important Files

- `PROJECT_DOC.md` - Comprehensive technical documentation (Chinese)
- `backend/agents.py` - LLM model configuration (change `MODEL_NAME` to switch models)
- `backend/main.py` - Middleware stack, CORS config, rate limiting policies
- `nginx.conf` - Production reverse proxy configuration

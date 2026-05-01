# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AI-driven 3D printing platform: operators upload STL/3MF files, the backend extracts geometry features, and an ML pipeline recommends optimal print settings (technology, material, parameters). Results can be exported as slicer profiles (Cura/PrusaSlicer).

**Stack**: FastAPI + PostgreSQL (backend) / Flutter + Riverpod (frontend)

---

## Commands

### Backend

```bash
cd backend

# Install dependencies
pip install -r requirements.txt

# Run dev server
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

# Run all tests
pytest

# Run a single test file
pytest app/tests/test_geometry_service.py -v

# Run tests with coverage
pytest --cov=app app/tests/

# Docker (both services)
docker-compose up
```

### Frontend

```bash
cd frontend

# Install dependencies
flutter pub get

# Run unit/widget tests
flutter test

# Run a single test file
flutter test test/auth/auth_viewmodel_test.dart

# Run integration tests
flutter test integration_test/app_test.dart

# Run app (desktop/device)
flutter run
```

---

## Architecture

### Backend — Clean Architecture (routers → services → models)

```
backend/app/
├── routers/        # HTTP layer: input validation, auth guards, response shaping
├── services/       # Business logic — all domain work lives here
├── models/         # SQLAlchemy ORM entities (User, STLFile, Recommendation, Printer, ...)
├── schemas/        # Pydantic request/response DTOs
└── core/           # Config, DB session, JWT security, email utilities
```

Key service responsibilities:
- `geometry_service.py` — mesh analysis via trimesh (volume, surface area, watertightness, overhang, wall thickness)
- `orientation_service.py` — optimal print orientation search
- `stl_service.py` — upload pipeline orchestrating geometry + orientation
- `recommendation_service.py` — technology/material/parameter selection
- `ml_inference.py` — ML model loading and inference
- `slicer_export_service.py` — Cura `.inst.cfg` and PrusaSlicer `.ini` profile generation
- `printer_service.py` — printer fleet CRUD

**Auth**: JWT access + refresh token rotation. Roles: `admin` / `operator`. Invitation-based user registration.

### Frontend — Clean Architecture + MVVM (Riverpod)

```
frontend/lib/
├── core/               # Theme, GoRouter config, constants, utils
├── features/
│   ├── auth/
│   ├── upload/
│   ├── recommendation/
│   ├── printers/
│   └── jobs/
└── main.dart
```

Each feature follows the same layered pattern:
```
<feature>/
├── data/
│   ├── api/            # Dio HTTP calls
│   ├── repositories/   # Concrete implementations (real + mock)
│   └── models/         # JSON-serializable models (Freezed)
├── domain/
│   ├── entities/       # Pure Dart domain objects
│   └── repositories/   # Abstract interfaces
└── presentation/
    ├── providers/       # Riverpod StateNotifierProvider declarations
    ├── viewmodels/      # StateNotifier subclasses (business logic)
    ├── screens/         # Full-page widgets
    └── widgets/         # Reusable UI components
```

**Routing**: GoRouter with a `MainShell` (bottom nav) wrapping authenticated routes (upload, recommendation, printers, jobs). Auth routes (login, register, password reset) render without the navbar. Deep links carry tokens in URL query params.

**State**: `StateNotifier` ViewModels; providers are declared separately from ViewModels (dependency injection pattern). Both real and mock repository implementations exist for testing.

### Backend–Frontend Communication

- REST over HTTP; multipart/form-data for file uploads; plain text for slicer exports
- `Authorization: Bearer <access_token>` on all authenticated requests
- Tokens stored in `flutter_secure_storage`; automatic refresh on 401

---

## Environment Setup

Copy `backend/.env.example` to `backend/.env` and fill in:

| Variable | Purpose |
|---|---|
| `DATABASE_URL` | PostgreSQL connection string |
| `SECRET_KEY` | JWT signing key |
| `ADMIN_SIGNUP_KEY` | Secret for the first admin registration |
| `SMTP_*` | Email delivery (Mailtrap for dev) |
| `APP_BASE_URL` | Frontend URL used in password-reset emails |

Docker Compose starts PostgreSQL 15 (`threedp_db`) and the FastAPI container together. Volumes persist STL uploads and GLB exports across restarts.

---

## Key Domain Concepts

- **STLFile**: uploaded mesh → geometry features extracted → status transitions (`uploaded → analyzing → ready | error`)
- **Recommendation**: ties an STLFile to a full set of print parameters; can be rated and re-parameterized; exported as slicer profile
- **Printer**: fleet entry with build volume, technology type, and Fernet-encrypted API key; connectivity to OctoPrint/PrusaLink is stubbed
- **Job**: queued print job referencing a Recommendation and a Printer — frontend model and screens exist, backend not yet started

---

## Feature Implementation State

### Auth — Complete

All 11 endpoints are production-ready. Logic is embedded in routers (no dedicated service layer).

**What's implemented:**
- Admin self-signup guarded by `ADMIN_SIGNUP_KEY`
- Invitation-based operator registration: admin calls `POST /admin/invitations` → token emailed → user registers at `POST /auth/register?token=...`
- JWT login with access + refresh token rotation; refresh tokens persisted in DB and revoked on logout or password reset
- Full password reset flow: forgot-password email → validate token → reset
- Role enforcement via `require_role()` FastAPI dependency (`admin` / `operator`)

**DB models**: `User`, `Invitation`, `PasswordResetToken`, `RefreshToken`

**Frontend**: 7 screens (splash, login, admin signup, register, invite user, forgot password, reset password) all wired end-to-end via `AuthViewModel`.

---

### Upload — Complete

All 8 endpoints are production-ready. The analysis pipeline runs as a FastAPI background task.

**What's implemented:**
- `POST /stl/upload` — validates extension (`.stl` / `.3mf`), enforces 50 MB limit, writes to disk, queues background analysis
- Background pipeline sequence: load mesh → extract 18 geometry features → compute top-3 orientations → convert to GLB preview → set status `ready` (or `error`)
- `GET /stl/{id}/glb` — serves GLB, optionally rotated to a selected orientation rank; grounds mesh to z=0 in-memory (no disk write)
- `POST /stl/{id}/reprocess` — re-runs the full pipeline

**18 geometry features extracted** (all real, no stubs):
`volume_cm3`, `surface_area_cm2`, `bbox_{x,y,z}_mm`, `triangle_count`, `overhang_ratio`, `max_overhang_angle`, `min/avg_wall_thickness_mm` (ray-cast), `complexity_index`, `aspect_ratio`, `is_watertight`, `shell_count`, `com_offset_ratio`, `flat_base_area_mm2`, `face_normal_histogram` (18-bin)

**Orientation algorithm** (`orientation_service.py`): deterministic two-stage Fibonacci sphere sampling — 200 coarse candidates, 24 fine refinements around the top 12 — scored on overhang area, support volume, base stability, and print height. Returns top 3 as `{rx_deg, ry_deg, rz_deg, overhang_reduction_pct, print_height_mm, score}`.

**Frontend**: `UploadScreen` (file picker → multipart upload) + `FileDetailScreen` (metadata + 3D GLB viewer + orientation selector). ViewModel polls every 2 s (up to 150 attempts / 5 min) until `status == "ready"`.

---

### Recommendation — Complete (ML models optional)

All 6 endpoints are production-ready. The ML pipeline has a rule-based fallback for development without trained models.

**What's implemented:**
- Three-stage ML pipeline in `ml_inference.py`:
  1. FDM vs SLA binary classifier (sklearn ensemble)
  2. Material classifier — 6 classes (PLA, ABS, PETG, TPU, Resin-Standard, Resin-Engineering)
  3. Parameter regressor — 6 outputs: `layer_height`, `infill_density`, `print_speed`, `wall_count`, `cooling_fan`, `support_density`
- 22 input features: 16 geometry fields from `STLFile` + 6 user intent fields (`intended_use`, `surface_finish`, `needs_flexibility`, `strength_required`, `budget_priority`, `outdoor_use`)
- Confidence scoring with per-stage thresholds; low-confidence triggers a clarification question
- Alternative recommendation computed when primary technology confidence is medium/low
- Uncertainty estimation: per-tree std dev → `layer_height_min/max` range
- Derived scores: `cost_score`, `quality_score`, `speed_score`
- `PATCH /recommend/{id}/parameters` — manual override of technology/material/any parameter
- `PATCH /recommend/{id}/rate` — 1–5 star user rating stored on the recommendation

**Slicer export** (`slicer_export_service.py`):
- `GET /recommend/{id}/export?format=cura` → Cura 5 `.inst.cfg`
- `GET /recommend/{id}/export?format=prusaslicer` → PrusaSlicer 2 `.ini`
- Profile name: `3DP_AI_{TECHNOLOGY}_{MATERIAL}`

**ML model files** must exist at `backend/models_ml/*.joblib` for real inference; otherwise `recommendation_service.py` falls back to a rule-based stub predictor automatically.

**Frontend**: 3 screens — multi-step intent form → result screen (scores, alternative, full parameters) → history list. `confidence_bar.dart` and `score_arc.dart` are reusable visual widgets.

---

### Printers — CRUD Complete, Connectivity Stubbed

5 of 7 endpoints are production-ready; 2 (status poll + connection test) return mock data.

**What's implemented:**
- Full CRUD: list (filterable by technology/status), detail, create, update, delete
- `connector_type` enum: `octoprint`, `prusalink`, `mock`, `manual` — field exists, but no actual HTTP calls to printers are made yet
- API keys encrypted at rest using **Fernet** symmetric encryption before DB storage; decryption helper exists for future connectivity code
- Printer fields: `build_volume_{x,y,z}`, `materials_supported` (JSON array), `status` enum (`idle`, `printing`, `error`, `offline`, `maintenance`)

**Stubbed:**
- `GET /printers/{id}/status` — returns mock status dict
- `POST /printers/{id}/test` — returns mock `{"ok": true}`
- No real HTTP calls to OctoPrint or PrusaLink yet

**Frontend**: 3 screens (list with filter, detail with 10 s status polling, create/edit form). `printer_status_badge.dart` widget reflects status enum visually.

---

### Jobs — Frontend Ready, Backend Not Started

The domain model, screens, and providers exist on the frontend; the entire backend is missing.

**What's done (frontend only):**
- `Job` entity with full field set: `status` enum (queued, scheduled, printing, completed, failed, canceled, paused), `priority`, `progressPct`, `estimatedDurationS`, `estimatedCost`, timestamps, computed helpers (`isCancelable`, `isActive`, `isFinished`)
- `JobQueueScreen` and `JobDetailScreen` UI screens
- Riverpod providers (`myJobsProvider`, `jobDetailProvider`, `submitJobProvider`)

**What's missing (entire backend):**
- No `Job` SQLAlchemy model
- No `job_service.py`
- No router / endpoints
- `job_repository_impl.dart` throws `UnimplementedError` on every method

**Planned endpoints** (from frontend TODOs):
```
POST   /jobs                    { stl_file_id, recommendation_id, printer_id, priority }
GET    /jobs                    list with status filter
GET    /jobs/{id}
PATCH  /jobs/{id}/cancel
PATCH  /jobs/{id}/suspend
PATCH  /jobs/{id}/resume
```

---

## Cross-Cutting Notes

- **No WebSockets yet**: printer status and job progress use polling (10 s and 2 s intervals respectively).
- **Mock repositories**: every feature has a `*_repository_mock.dart` for offline/test use; swap via provider injection.
- **Status corrections in CLAUDE.md vs code**: STLFile status is `uploaded → analyzing → ready | error` (not `pending → processing → completed`).

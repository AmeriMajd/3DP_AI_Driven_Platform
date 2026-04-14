# Integration Tests Guide

Quick reference for running integration tests for the 3DP AI-Driven Platform.

## Backend Integration Tests (Python/FastAPI)

### Setup
```bash
cd backend
pip install -r requirements.txt
```

### Run All Tests
```bash
pytest
```

### Run Specific Test File
```bash
pytest app/tests/test_geometry_service.py
pytest app/tests/test_orientation_service.py
pytest app/tests/test_stl_upload_flow.py
```

### Run Tests with Coverage
```bash
pytest --cov=app app/tests/
```

### Run Tests Verbosely
```bash
pytest -v
```

### Run Only Geometry Tests
```bash
pytest app/tests/test_geometry_service.py -v
```

---

## Frontend Integration Tests (Flutter)

### Setup
```bash
cd frontend
flutter pub get
```

### Run Unit Tests (Widgets & Providers)
```bash
flutter test
```

### Run Specific Test File
```bash
flutter test test/providers_test.dart
flutter test test/test_utils.dart
```

### Run Integration Tests (Full App)
```bash
flutter test integration_test/app_test.dart
```

### Run Integration Tests on Device/Emulator
```bash
# Start an emulator or connect a device first
flutter drive \
  --target=integration_test/app_test.dart \
  --driver=test_driver/integration_test.dart
```

---

## Test Coverage

### Backend (4–5 Tests)
✅ **Geometry Service** (`test_geometry_service.py`):
- Geometry extraction on cube mesh
- Bounding box calculation
- Watertight detection
- Shell counting
- All geometry fields present
- Aspect ratio & complexity
- CoM offset verification

✅ **Orientation Service** (`test_orientation_service.py`):
- Top-3 orientation selection
- Result structure validation
- Score validity [0, 1]
- Rank ordering
- Angle ranges [-180, 180]
- Metric positivity
- Overhang reduction %
- Budget priority (speed)
- Surface finish (fine)
- Diversity filtering

✅ **STL Upload Flow** (`test_stl_upload_flow.py`):
- File upload success
- File status tracking
- List user files
- File deletion
- Auth requirement
- File size tracking
- Processing status
- User file isolation

### Frontend (3–5 Tests)
✅ **Integration Tests** (`integration_test/app_test.dart`):
- Navigate to upload screen
- Upload screen UI elements
- File detail screen navigation
- Tab navigation (Geometry, Orientation, 3D Preview)
- 3D viewer rendering
- Delete button visibility

✅ **Provider Tests** (`test/providers_test.dart`):
- Mock data factory
- Geometry field validation
- Orientation result structure
- Orientation score ordering
- File status transitions
- Orientation metric ranges
- Multi-orientation lists

---

## Key Features Tested

### Upload Pipeline
- STL file upload → database storage
- File size tracking
- Status progression (uploaded → analyzing → ready)
- User isolation (files belong to user)

### Geometry Analysis
- Volume & surface area extraction
- Bounding box dimensions (mm)
- Triangle count
- Watertightness detection
- Shell counting
- Wall thickness analysis
- Complexity indexing
- Aspect ratio
- Center of mass offset

### Orientation Optimization
- Fibonacci sphere sampling (162-200 candidates)
- Multi-factor scoring (overhang, base, height, support, stability)
- Top-3 diverse orientation selection
- Budget priority (speed vs. quality)
- Surface finish preferences
- Detailed metrics per orientation

---

## Running All Tests at Once

### Backend Only
```bash
cd backend && pytest --tb=short
```

### Frontend Only
```bash
cd frontend && flutter test
```

### Both (from root)
```bash
# Backend
cd backend && pytest

# Then Frontend
cd ../frontend && flutter test
```

---

## CI/CD Integration

### GitHub Actions Example
```yaml
name: Integration Tests

on: [push, pull_request]

jobs:
  backend-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      - run: cd backend && pip install -r requirements.txt
      - run: cd backend && pytest --tb=short

  frontend-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: cd frontend && flutter pub get
      - run: cd frontend && flutter test
```

---

## Troubleshooting

### Backend Tests Fail - Database Issues
- Tests use in-memory SQLite by default
- Ensure pytest-asyncio is installed: `pip install pytest-asyncio`

### Frontend Tests Fail - Widget Binding
- Run from the `frontend` directory
- Ensure Flutter SDK is in PATH

### Integration Tests Won't Run
- For Flutter integration tests, ensure emulator/device is running
- Check: `flutter devices`

---

## Next Steps

- Add API integration tests (mock HTTP responses)
- Add E2E tests with real STL test files
- Set up continuous test runs in CI/CD pipeline
- Monitor test coverage trends

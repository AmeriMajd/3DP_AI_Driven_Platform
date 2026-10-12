# Print AI frontend

## Portfolio demo

The `production-demo` branch builds a self-contained Flutter web demo for
GitHub Pages. It uses sample data for authentication, STL analysis,
recommendations, printer fleet management, jobs, and the profile screen; it
does not connect to the FastAPI API, a database, or real printers.

Build it locally with:

```bash
flutter pub get
flutter build web --release \
  --base-href "/3DP_AI_Driven_Platform/" \
  --dart-define=DEMO_MODE=true
```

Pushes to `production-demo` are built and deployed by
`.github/workflows/deploy-demo.yml`. In the repository settings, set Pages to
deploy from **GitHub Actions**. The expected public URL is:

```text
https://amerimajd.github.io/3DP_AI_Driven_Platform/
```

## API-connected builds

Without `--dart-define=DEMO_MODE=true`, the app keeps its existing API-backed
repositories. A local `.env` file is optional and is intended only for local
API configuration; it is not bundled in the portfolio build.

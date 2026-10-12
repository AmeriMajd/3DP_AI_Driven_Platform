/// Enables the self-contained portfolio experience at build time.
///
/// Build with `--dart-define=DEMO_MODE=true` to use sample data instead of the
/// FastAPI service. Keep the default false for local and production API builds.
const bool isDemoMode = bool.fromEnvironment(
  'DEMO_MODE',
  defaultValue: false,
);

/// Noms et chemins de toutes les routes de l'application.
/// Utiliser ces constantes partout — jamais de strings en dur.
class AppRoutes {
  AppRoutes._();

  // ── Auth ──
  static const String adminSignup = '/admin-signup';
  static const String inviteUser  = '/invite';
  static const String register    = '/register';
  static const String login    = '/login';
  static const String forgotPassword ='/forgot-password';
  static const String resetPassword = '/reset-password';

  // ── Dashboard (à venir) ──
  static const String dashboard   = '/dashboard';
}
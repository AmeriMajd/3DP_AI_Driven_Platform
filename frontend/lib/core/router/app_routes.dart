/// Noms et chemins de toutes les routes de l'application.
/// Utiliser ces constantes partout — jamais de strings en dur.
class AppRoutes {
  AppRoutes._();

  // ── Auth ──
  static const String adminSignup = '/admin-signup';
  static const String inviteUser  = '/invite';
  static const String register    = '/register';

  // ── Dashboard (à venir) ──
  static const String dashboard   = '/dashboard';
}
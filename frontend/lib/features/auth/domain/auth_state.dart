enum AuthStatus { initial, loading, success, error }

enum SessionStatus { unknown, notInitialized, unauthenticated, authenticated }

class AuthState {
  final AuthStatus status;
  final SessionStatus sessionStatus;
  final String? errorMessage;
  final String? successMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.sessionStatus = SessionStatus.unknown,
    this.errorMessage,
    this.successMessage,
  });

  bool get isLoading => status == AuthStatus.loading;

  AuthState copyWith({
    AuthStatus? status,
    SessionStatus? sessionStatus,
    String? errorMessage,
    String? successMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      sessionStatus: sessionStatus ?? this.sessionStatus,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

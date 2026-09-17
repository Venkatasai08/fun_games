import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/auth_service.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  bool _isLogin = true;
  bool _obscurePassword = true;

  AuthBloc() : super(const AuthInitial()) {
    on<AuthTabToggled>(_onTabToggled);
    on<AuthPasswordVisibilityToggled>(_onPasswordVisibilityToggled);
    on<AuthLoginRequested>(_onLogin);
    on<AuthRegisterRequested>(_onRegister);
    on<AuthGuestRequested>(_onGuest);
    on<AuthSignOutRequested>(_onSignOut);
    on<AuthForgotPasswordRequested>(_onForgotPassword);
  }

  void _onTabToggled(AuthTabToggled event, Emitter<AuthState> emit) {
    _isLogin = event.isLogin;
    emit(AuthInitial(isLogin: _isLogin, obscurePassword: _obscurePassword));
  }

  void _onPasswordVisibilityToggled(
      AuthPasswordVisibilityToggled event, Emitter<AuthState> emit) {
    _obscurePassword = !_obscurePassword;
    emit(AuthInitial(isLogin: _isLogin, obscurePassword: _obscurePassword));
  }

  Future<void> _onLogin(
      AuthLoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await AuthService.signIn(email: event.email, password: event.password);
      emit(AuthSuccess());
    } catch (e) {
      emit(AuthFailure(_friendlyError(e)));
    }
  }

  Future<void> _onRegister(
      AuthRegisterRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      if (event.isGuestUpgrade) {
        await AuthService.upgradeGuestToAccount(
          email: event.email,
          password: event.password,
          username: event.username,
        );
      } else {
        await AuthService.register(
          email: event.email,
          password: event.password,
          username: event.username,
        );
      }
      emit(AuthSuccess());
    } catch (e) {
      emit(AuthFailure(_friendlyError(e)));
    }
  }

  Future<void> _onGuest(
      AuthGuestRequested event, Emitter<AuthState> emit) async {
    emit(AuthGuestLoading());
    try {
      await AuthService.signInAsGuest(event.name);
      emit(AuthSuccess());
    } catch (e) {
      emit(AuthFailure(_friendlyError(e)));
    }
  }

  Future<void> _onSignOut(
      AuthSignOutRequested event, Emitter<AuthState> emit) async {
    await AuthService.signOut();
  }

  Future<void> _onForgotPassword(
      AuthForgotPasswordRequested event, Emitter<AuthState> emit) async {
    try {
      await AuthService.sendPasswordReset(event.email);
      emit(AuthForgotPasswordSent());
    } catch (e) {
      emit(AuthFailure(_friendlyError(e)));
    }
  }

  /// Extracts a human-friendly message from Firebase or generic exceptions.
  String _friendlyError(Object e) {
    if (e is Exception) {
      final msg = e.toString();
      // Strip the "Exception: " / "FirebaseAuthException: " prefix Flutter adds
      final match = RegExp(r'\] (.+)$').firstMatch(msg);
      if (match != null) return match.group(1)!;
      return msg.replaceFirst(RegExp(r'^.*Exception: '), '');
    }
    return e.toString();
  }
}

part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;
  const AuthLoginRequested({required this.email, required this.password});
  @override
  List<Object?> get props => [email, password];
}

class AuthRegisterRequested extends AuthEvent {
  final String email;
  final String password;
  final String username;
  final bool isGuestUpgrade;
  const AuthRegisterRequested({
    required this.email,
    required this.password,
    required this.username,
    this.isGuestUpgrade = false,
  });
  @override
  List<Object?> get props => [email, password, username, isGuestUpgrade];
}

class AuthGuestRequested extends AuthEvent {
  final String name;
  const AuthGuestRequested({required this.name});
  @override
  List<Object?> get props => [name];
}

class AuthSignOutRequested extends AuthEvent {}

class AuthForgotPasswordRequested extends AuthEvent {
  final String email;
  const AuthForgotPasswordRequested({required this.email});
  @override
  List<Object?> get props => [email];
}

class AuthTabToggled extends AuthEvent {
  final bool isLogin;
  const AuthTabToggled({required this.isLogin});
  @override
  List<Object?> get props => [isLogin];
}

class AuthPasswordVisibilityToggled extends AuthEvent {}

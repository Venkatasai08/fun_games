part of 'auth_bloc.dart';

abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  final bool isLogin;
  final bool obscurePassword;
  const AuthInitial({this.isLogin = true, this.obscurePassword = true});
  @override
  List<Object?> get props => [isLogin, obscurePassword];
}

class AuthLoading extends AuthState {}

class AuthGuestLoading extends AuthState {}

class AuthSuccess extends AuthState {}

class AuthForgotPasswordSent extends AuthState {}

class AuthFailure extends AuthState {
  final String message;
  const AuthFailure(this.message);
  @override
  List<Object?> get props => [message];
}

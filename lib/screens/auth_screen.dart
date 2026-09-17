// lib/screens/auth_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../config/app_theme.dart';
import '../blocs/auth/auth_bloc.dart';

class AuthScreen extends StatelessWidget {
  final String? prefilledUsername;
  final bool isGuestUpgrade;
  const AuthScreen({
    super.key,
    this.prefilledUsername,
    this.isGuestUpgrade = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(state.message), backgroundColor: Colors.red),
          );
        }
        if (state is AuthForgotPasswordSent) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password reset email sent!')),
          );
        }
        if (state is AuthSuccess && isGuestUpgrade) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
      child: _AuthScreenBody(
        prefilledUsername: prefilledUsername,
        isGuestUpgrade: isGuestUpgrade,
      ),
    );
  }
}

// ── Body — controllers live here so they survive BlocBuilder rebuilds ─────────

class _AuthScreenBody extends StatefulWidget {
  final String? prefilledUsername;
  final bool isGuestUpgrade;
  const _AuthScreenBody({this.prefilledUsername, this.isGuestUpgrade = false});

  @override
  State<_AuthScreenBody> createState() => _AuthScreenBodyState();
}

class _AuthScreenBodyState extends State<_AuthScreenBody> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  late final TextEditingController _usernameCtrl;

  @override
  void initState() {
    super.initState();
    _usernameCtrl = TextEditingController(text: widget.prefilledUsername ?? '');
    if (widget.prefilledUsername != null) {
      context.read<AuthBloc>().add(const AuthTabToggled(isLogin: false));
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  void _submit(bool isLogin) {
    if (!_formKey.currentState!.validate()) return;
    if (isLogin) {
      context.read<AuthBloc>().add(AuthLoginRequested(
            email: _emailCtrl.text,
            password: _passwordCtrl.text,
          ));
    } else {
      context.read<AuthBloc>().add(AuthRegisterRequested(
            email: _emailCtrl.text,
            password: _passwordCtrl.text,
            username: _usernameCtrl.text,
            isGuestUpgrade: widget.isGuestUpgrade,
          ));
    }
  }

  void _showGuestDialog() {
    showDialog(
      context: context,
      builder: (ctx) => BlocProvider.value(
        value: context.read<AuthBloc>(),
        child: const _GuestDialog(),
      ),
    );
  }

  void _showForgotPassword() {
    final emailCtrl = TextEditingController(text: _emailCtrl.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reset Password'),
        content: TextField(
          controller: emailCtrl,
          decoration: const InputDecoration(labelText: 'Email address'),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context
                  .read<AuthBloc>()
                  .add(AuthForgotPasswordRequested(email: emailCtrl.text));
            },
            child: const Text('Send Reset Email'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final isLogin = state is AuthInitial ? state.isLogin : true;
        final obscurePassword =
            state is AuthInitial ? state.obscurePassword : true;
        final isLoading = state is AuthLoading;
        final isGuestLoading = state is AuthGuestLoading;

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F0E1A),
                  Color(0xFF1A1040),
                  Color(0xFF0F0E1A)
                ],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLogo(),
                      const SizedBox(height: 40),
                      _buildAuthCard(isLogin, obscurePassword, isLoading),
                      const SizedBox(height: 20),
                      _buildGuestButton(isGuestLoading),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primary, AppTheme.primaryLight],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.4),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.sports_esports_rounded,
              size: 44, color: Colors.white),
        ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
        const SizedBox(height: 16),
        const Text('FUN GAMES',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: 6,
              color: Colors.white,
            )).animate().fadeIn(delay: 200.ms),
        const SizedBox(height: 4),
        const Text('Play together, win together',
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14)).animate().fadeIn(delay: 350.ms),
      ],
    );
  }

  Widget _buildAuthCard(bool isLogin, bool obscurePassword, bool isLoading) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tab switcher
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.bgDark,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _tabButton('Login', true, isLogin),
                    _tabButton('Register', false, isLogin),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              if (!isLogin) ...[
                TextFormField(
                  controller: _usernameCtrl,
                  readOnly: widget.prefilledUsername != null,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    prefixIcon: const Icon(Icons.person_outline),
                    suffixIcon: widget.prefilledUsername != null
                        ? const Tooltip(
                            message: 'Name carried over from guest session',
                            child: Icon(Icons.lock_outline,
                                size: 18,
                                color: AppTheme.textSecondary),
                          )
                        : null,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Username required';
                    if (v.trim().length < 3) return 'Min 3 characters';
                    return null;
                  },
                ).animate().slideY(begin: -0.2, duration: 300.ms),
                const SizedBox(height: 16),
              ],

              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Email required';
                  if (!v.contains('@')) return 'Invalid email';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _passwordCtrl,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: () => context
                        .read<AuthBloc>()
                        .add(AuthPasswordVisibilityToggled()),
                    icon: Icon(obscurePassword
                        ? Icons.visibility_off
                        : Icons.visibility),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Password required';
                  if (v.length < 6) return 'Min 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 28),

              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: isLoading ? null : () => _submit(isLogin),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          isLogin ? 'Login' : 'Create Account',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),

              if (isLogin) ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _showForgotPassword,
                  child: const Text('Forgot password?',
                      style: TextStyle(color: AppTheme.textSecondary)),
                ),
              ],
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1);
  }

  Widget _buildGuestButton(bool isGuestLoading) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Divider(color: AppTheme.border)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('or',
                    style: TextStyle(
                        color: AppTheme.textSecondary.withOpacity(0.6),
                        fontSize: 13)),
              ),
              Expanded(child: Divider(color: AppTheme.border)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: isGuestLoading ? null : _showGuestDialog,
              icon: isGuestLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.textSecondary),
                    )
                  : const Icon(Icons.person_outline, size: 20),
              label: Text(
                isGuestLoading ? 'Joining...' : 'Join as Guest',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                side: BorderSide(color: AppTheme.border, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 550.ms).slideY(begin: 0.1);
  }

  Widget _tabButton(String label, bool isLoginTab, bool currentIsLogin) {
    final selected = currentIsLogin == isLoginTab;
    return Expanded(
      child: GestureDetector(
        onTap: () => context
            .read<AuthBloc>()
            .add(AuthTabToggled(isLogin: isLoginTab)),
        child: AnimatedContainer(
          duration: 250.ms,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.primaryLight])
                : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : AppTheme.textSecondary,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Guest Dialog — fully driven by AuthBloc, zero setState ───────────────────

class _GuestDialog extends StatefulWidget {
  const _GuestDialog();

  @override
  State<_GuestDialog> createState() => _GuestDialogState();
}

class _GuestDialogState extends State<_GuestDialog> {
  final _nameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    // Dispatch to BLoC — loading state handled by AuthGuestLoading
    context
        .read<AuthBloc>()
        .add(AuthGuestRequested(name: _nameCtrl.text.trim()));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final isLoading = state is AuthGuestLoading;

        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.border),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.15),
                  blurRadius: 32,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF2D1F6E), AppTheme.bgCard],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.person_outline,
                            color: AppTheme.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Join as Guest',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                            Text('No account needed',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: isLoading ? null : () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppTheme.bgCardLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              color: AppTheme.textSecondary, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
                // Body
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Choose a display name to play with friends.',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _nameCtrl,
                          autofocus: true,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Your Name',
                            hintText: 'e.g. Rahul',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty)
                              return 'Name is required';
                            if (v.trim().length < 2) return 'Min 2 characters';
                            if (v.trim().length > 20)
                              return 'Max 20 characters';
                            return null;
                          },
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.warning.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: AppTheme.warning.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline,
                                  size: 16,
                                  color: AppTheme.warning.withOpacity(0.8)),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Guests can join & play rooms but cannot create them.',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Enter as Guest',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

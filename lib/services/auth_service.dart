import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';

/// Thin wrapper around Supabase Auth. Profile-row creation on sign-up is
/// handled server-side by the `handle_new_user` trigger (see
/// supabase/schema.sql) — it reads `full_name` / `role` / `facility` and the
/// trainer slot-form defaults straight out of the `data` payload passed to
/// signUp().
class AuthService {
  GoTrueClient get _auth => supabase.auth;

  User? get currentUser => _auth.currentUser;
  String? get currentUserId => _auth.currentUser?.id;
  bool get isSignedIn => _auth.currentUser != null;

  Stream<AuthState> get onAuthStateChange => _auth.onAuthStateChange;

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required String role, // 'trainer' | 'rider'
    String? facility,
    int? defaultDurationMinutes,
    String? defaultSlotMode,
    String? defaultRepeat,
  }) async {
    await _auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'role': role,
        'facility': ?facility,
        'default_duration_minutes': ?defaultDurationMinutes,
        'default_slot_mode': ?defaultSlotMode,
        'default_repeat': ?defaultRepeat,
      },
    );
  }

  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Re-sends the sign-up confirmation email. Supabase rate-limits this
  /// server-side (~60s); the UI additionally enforces a 30s cooldown.
  Future<void> resendConfirmationEmail(String email) async {
    await _auth.resend(type: OtpType.signup, email: email);
  }

  /// Step 1 of "Passwort vergessen": sends the recovery email. With the
  /// email template set to include `{{ .Token }}`, the user gets a 6-digit
  /// code they type back into the app.
  Future<void> sendPasswordResetCode(String email) async {
    await _auth.resetPasswordForEmail(email);
  }

  /// Step 2: verify the 6-digit code from the recovery email. On success the
  /// user is signed in and [updatePassword] can be called.
  Future<void> verifyPasswordResetCode({
    required String email,
    required String token,
  }) async {
    await _auth.verifyOTP(
      type: OtpType.recovery,
      email: email,
      token: token,
    );
  }

  /// Step 3: set the new password for the (now authenticated) user.
  Future<void> updatePassword(String newPassword) async {
    await _auth.updateUser(UserAttributes(password: newPassword));
  }
}

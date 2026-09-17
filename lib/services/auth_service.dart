// lib/services/auth_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Central service for all authentication and user profile logic.
///
/// Firestore structure (top-level):
///   profiles/{uid}   ← user profile documents (all users, guests + registered)
///   fun_games/       ← top-level app stats document
class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _db = FirebaseFirestore.instance;

  // ── Collection refs ────────────────────────────────────────────────────────

  /// Top-level profiles collection — one doc per UID.
  static CollectionReference get _profiles => _db.collection('profiles');

  /// App-level stats document.
  static DocumentReference get _appStats =>
      _db.collection('fun_games').doc('stats');

  // ── SharedPreferences keys ─────────────────────────────────────────────────

  static const _keyGuestName = 'guest_name';
  static const _keyGuestUid = 'guest_uid';

  // ── Getters ────────────────────────────────────────────────────────────────

  static User? get currentUser => _auth.currentUser;
  static bool get isLoggedIn => currentUser != null;
  static bool get isGuest => currentUser?.isAnonymous ?? false;

  /// Returns true if the current user has `is_admin: true` in their profile.
  static Future<bool> isAdmin() async {
    final uid = currentUser?.uid;
    if (uid == null) return false;
    try {
      final doc = await _profiles.doc(uid).get();
      return (doc.data() as Map<String, dynamic>?)?['is_admin'] as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  // ── Profile helpers ────────────────────────────────────────────────────────

  /// Returns the username for [uid] from Firestore.
  /// Falls back to the locally stored guest name, then 'Guest'.
  static Future<String> getUsername(String uid) async {
    try {
      final doc = await _profiles.doc(uid).get();
      final name =
          (doc.data() as Map<String, dynamic>?)?['username'] as String?;
      if (name != null && name.isNotEmpty) return name;
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyGuestName) ?? 'Guest';
  }

  /// Creates or merges a profile document at `profiles/{uid}`.
  static Future<void> createProfile(
    String uid,
    String username,
    String email, {
    bool isGuest = false,
  }) async {
    await _profiles.doc(uid).set({
      'username': username,
      'email': email,
      'avatar_color': isGuest ? '#B0AECF' : '#6C63FF',
      'is_guest': isGuest,
      'is_admin': false,
      'created_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!isGuest) await _incrementStat('total_users', 1);
  }

  /// Upgrades a guest profile to a full registered account in-place.
  static Future<void> upgradeGuestProfile(
    String uid,
    String username,
    String email,
  ) async {
    await _profiles.doc(uid).update({
      'username': username,
      'email': email,
      'avatar_color': '#6C63FF',
      'is_guest': false,
      'upgraded_at': FieldValue.serverTimestamp(),
    });
    await _incrementStat('total_users', 1);
  }

  // ── Auth actions ───────────────────────────────────────────────────────────

  /// Signs in with email + password.
  static Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Registers a new account and creates the profile doc.
  static Future<void> register({
    required String email,
    required String password,
    required String username,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
    if (cred.user != null) {
      await createProfile(
        cred.user!.uid,
        username.trim(),
        email.trim(),
      );
    }
  }

  /// Upgrades the current anonymous session to a real account by linking
  /// email credentials. Preserves the same UID so all game data is kept.
  static Future<void> upgradeGuestToAccount({
    required String email,
    required String password,
    required String username,
  }) async {
    final credential = EmailAuthProvider.credential(
      email: email.trim(),
      password: password.trim(),
    );
    final linked =
        await _auth.currentUser!.linkWithCredential(credential);
    await upgradeGuestProfile(
      linked.user!.uid,
      username.trim(),
      email.trim(),
    );
    await clearGuestPrefs();
  }

  /// Signs in anonymously, stores the display name locally and in Firestore.
  static Future<void> signInAsGuest(String displayName) async {
    final name = displayName.trim();
    final prefs = await SharedPreferences.getInstance();
    final savedUid = prefs.getString(_keyGuestUid);
    final current = _auth.currentUser;

    // Re-use an existing anonymous session if UIDs match
    if (current != null && current.isAnonymous && current.uid == savedUid) {
      await prefs.setString(_keyGuestName, name);
      return;
    }

    final credential = await _auth.signInAnonymously();
    final uid = credential.user!.uid;

    await prefs.setString(_keyGuestName, name);
    await prefs.setString(_keyGuestUid, uid);

    await createProfile(uid, name, '', isGuest: true);
  }

  /// Signs out (works for both guests and registered users).
  static Future<void> signOut() async {
    if (isGuest) await clearGuestPrefs();
    await _auth.signOut();
  }

  /// Sends a password reset email.
  static Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // ── Session restore ────────────────────────────────────────────────────────

  /// Called on app startup to validate any persisted anonymous session.
  static Future<void> restoreSession() async {
    final current = _auth.currentUser;
    if (current == null || !current.isAnonymous) return;

    final prefs = await SharedPreferences.getInstance();
    final savedUid = prefs.getString(_keyGuestUid);

    // Stale prefs from a previous install — clear them
    if (savedUid != null && savedUid != current.uid) {
      await prefs.remove(_keyGuestName);
      await prefs.remove(_keyGuestUid);
    }
  }

  /// Returns the locally stored guest display name, or null if not a guest.
  static Future<String?> getGuestName() async {
    if (!isGuest) return null;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyGuestName);
  }

  /// Removes guest prefs without signing out (used after upgrade).
  static Future<void> clearGuestPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyGuestName);
    await prefs.remove(_keyGuestUid);
  }

  // ── Stats helper ───────────────────────────────────────────────────────────

  static Future<void> _incrementStat(String field, int delta) async {
    await _appStats.set({
      field: FieldValue.increment(delta),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

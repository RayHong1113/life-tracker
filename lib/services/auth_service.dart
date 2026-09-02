import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'database_helper.dart';
import 'cloud_sync_service.dart';
import 'firebase_service.dart';

class GoogleUserInfo {
  final String email;
  final String displayName;
  final String? photoUrl;
  final String? id;

  GoogleUserInfo({
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.id,
  });
}

class AuthService {
  static final AuthService instance = AuthService._init();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  GoogleUserInfo? _currentUser;
  bool _isInitialized = false;

  AuthService._init();

  GoogleUserInfo? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      await FirebaseService.instance.init();
      final fbUser = FirebaseService.instance.currentUser;

      if (fbUser != null && fbUser.email != null) {
        _currentUser = GoogleUserInfo(
          email: fbUser.email!,
          displayName: fbUser.displayName ?? fbUser.email!.split('@').first,
          photoUrl: fbUser.photoURL,
          id: fbUser.uid,
        );
      } else {
        final email = await DatabaseHelper.instance.getSetting('google_user_email');
        final name = await DatabaseHelper.instance.getSetting('google_user_name');
        final photo = await DatabaseHelper.instance.getSetting('google_user_photo');
        final id = await DatabaseHelper.instance.getSetting('google_user_id');

        if (email != null && email.isNotEmpty) {
          _currentUser = GoogleUserInfo(
            email: email,
            displayName: name ?? email.split('@').first,
            photoUrl: photo,
            id: id,
          );
        }
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint('AuthService init error: $e');
    }
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Register new user account with Firebase Cloud Auth & Local SQLite
  Future<GoogleUserInfo> signUp(String email, String password) async {
    final trimmedEmail = email.trim().toLowerCase();
    if (trimmedEmail.isEmpty || !trimmedEmail.contains('@')) {
      throw Exception('Please enter a valid email address');
    }
    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters long');
    }

    try {
      await FirebaseService.instance.signUpWithFirebase(trimmedEmail, password);
    } catch (e) {
      debugPrint('Firebase Cloud Auth Sign Up Error: $e');
      rethrow;
    }

    final passwordHash = _hashPassword(password);
    await DatabaseHelper.instance.registerUser(trimmedEmail, passwordHash);

    return await signIn(trimmedEmail, password);
  }

  /// Authenticate existing user with Real Google Firebase Cloud
  Future<GoogleUserInfo> signIn(String email, String password) async {
    final trimmedEmail = email.trim().toLowerCase();
    if (trimmedEmail.isEmpty) {
      throw Exception('Email cannot be empty');
    }
    if (password.isEmpty) {
      throw Exception('Password cannot be empty');
    }

    try {
      await FirebaseService.instance.signInWithFirebase(trimmedEmail, password);
    } catch (e) {
      debugPrint('Firebase Cloud Auth Sign In Error: $e');
      rethrow;
    }

    final displayName = trimmedEmail.split('@').first;
    _currentUser = GoogleUserInfo(
      email: trimmedEmail,
      displayName: displayName,
    );

    await DatabaseHelper.instance.saveSetting('google_user_email', trimmedEmail);
    await DatabaseHelper.instance.saveSetting('google_user_name', displayName);
    await DatabaseHelper.instance.saveSetting('google_user_id', trimmedEmail);

    return _currentUser!;
  }

  /// Launch Official Google Web OAuth Authorization Page (accounts.google.com)
  Future<bool> signInWithGoogleOAuthWeb() async {
    try {
      if (CloudSyncService.instance.isConfigured) {
        final success = await supabase.Supabase.instance.client.auth.signInWithOAuth(
          supabase.OAuthProvider.google,
          redirectTo: 'lifetracker://login-callback',
        );
        return success;
      }
    } catch (e) {
      debugPrint('Google Web OAuth Error: $e');
    }
    return false;
  }

  Future<GoogleUserInfo?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account != null) {
        final GoogleSignInAuthentication auth = await account.authentication;
        final idToken = auth.idToken;
        final accessToken = auth.accessToken;

        if (idToken != null || accessToken != null) {
          final credential = GoogleAuthProvider.credential(
            accessToken: accessToken,
            idToken: idToken,
          );
          await FirebaseAuth.instance.signInWithCredential(credential);
        }

        _currentUser = GoogleUserInfo(
          email: account.email,
          displayName: account.displayName ?? account.email.split('@').first,
          photoUrl: account.photoUrl,
          id: account.id,
        );

        await DatabaseHelper.instance
            .saveSetting('google_user_email', account.email);
        await DatabaseHelper.instance.saveSetting(
            'google_user_name', _currentUser!.displayName);
        if (account.photoUrl != null) {
          await DatabaseHelper.instance
              .saveSetting('google_user_photo', account.photoUrl!);
        }
        await DatabaseHelper.instance
            .saveSetting('google_user_id', account.id);

        await FirebaseService.instance.syncFullFirestore();

        return _currentUser;
      }
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      rethrow;
    }
    return null;
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    try {
      await FirebaseService.instance.signOut();
    } catch (_) {}

    _currentUser = null;
    await DatabaseHelper.instance.saveSetting('google_user_email', '');
    await DatabaseHelper.instance.saveSetting('google_user_name', '');
    await DatabaseHelper.instance.saveSetting('google_user_photo', '');
    await DatabaseHelper.instance.saveSetting('google_user_id', '');

    await DatabaseHelper.instance.clearLocalUserData();
  }
}

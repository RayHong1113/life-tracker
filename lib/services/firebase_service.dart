import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'database_helper.dart';
import '../models/activity_label.dart';

class FirebaseService {
  static final FirebaseService instance = FirebaseService._init();

  bool _isInitialized = false;

  FirebaseService._init();

  bool get isInitialized => _isInitialized;
  User? get currentUser {
    try {
      return FirebaseAuth.instance.currentUser;
    } catch (_) {
      return null;
    }
  }
  bool get isSignedIn => currentUser != null;

  static const FirebaseOptions _firebaseOptions = FirebaseOptions(
    apiKey: 'AIzaSyA7tZ4M929KYapnH04IT38kW65OV9a_t3c',
    appId: '1:625366027682:android:ebae7207971b3aa67036fb',
    messagingSenderId: '625366027682',
    projectId: 'lifetracker-70b80',
    storageBucket: 'lifetracker-70b80.firebasestorage.app',
  );

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      try {
        Firebase.app();
      } catch (_) {
        await Firebase.initializeApp(options: _firebaseOptions);
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint('Firebase init error: $e');
    }
  }

  /// Real Google Firebase Online Account Registration
  Future<UserCredential> signUpWithFirebase(
      String email, String password) async {
    await init();
    try {
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      try {
        await credential.user?.sendEmailVerification();
      } catch (e) {
        debugPrint('Send email verification error: $e');
      }
      // Purge leftover local database cache before populating new user workspace
      await DatabaseHelper.instance.clearLocalUserData();
      await syncFullFirestore();
      return credential;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw Exception('Account already exists in Firebase. Please sign in instead.');
      } else if (e.code == 'weak-password') {
        throw Exception('Password is too weak. Please use at least 6 characters.');
      }
      throw Exception(e.message ?? 'Firebase Sign Up failed');
    }
  }

  /// Real Google Firebase Online Authentication Check
  Future<UserCredential> signInWithFirebase(
      String email, String password) async {
    await init();
    try {
      final credential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await pullCloudFirestoreToLocal(isAccountSwitch: true);
      return credential;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw Exception('Incorrect password. Firebase access denied.');
      } else if (e.code == 'user-not-found') {
        throw Exception('Account not found on Firebase. Please click Sign Up to register.');
      }
      throw Exception(e.message ?? 'Firebase Sign In failed');
    }
  }

  Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
  }

  /// Full Real-time Bidirectional Firestore Database Syncing
  Future<int> syncFullFirestore() async {
    final user = currentUser;
    if (user == null) return 0;

    final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
    int count = 0;

    try {
      // 1. Push local SQLite records to Firebase Firestore Cloud
      final backupData = await DatabaseHelper.instance.exportBackupData();
      final localActivities =
          backupData['activity_logs'] as List<Map<String, dynamic>>? ?? [];
      final localCategories =
          backupData['categories'] as List<Map<String, dynamic>>? ?? [];

      for (var cat in localCategories) {
        await userDoc.collection('categories').doc(cat['id'].toString()).set(cat);
      }
      for (var act in localActivities) {
        await userDoc.collection('activity_logs').doc(act['id'].toString()).set(act);
      }
      final localLabels = await DatabaseHelper.instance.getAllLabels();
      for (var lbl in localLabels) {
        await userDoc.collection('labels').doc(lbl.id).set(lbl.toMap());
      }

      // 2. Pull Cloud Firestore records and merge into local SQLite DB
      final catSnap = await userDoc.collection('categories').get();
      final actSnap = await userDoc.collection('activity_logs').get();
      final lblSnap = await userDoc.collection('labels').get();

      final cloudCategories = catSnap.docs.map((d) => d.data()).toList();
      final cloudActivities = actSnap.docs.map((d) => d.data()).toList();

      for (var doc in lblSnap.docs) {
        await DatabaseHelper.instance.insertLabel(ActivityCategoryLabel.fromMap(doc.data()));
      }

      final cloudData = {
        'categories': cloudCategories,
        'activity_logs': cloudActivities,
      };

      count = await DatabaseHelper.instance.importBackupData(cloudData);
    } catch (e) {
      debugPrint('Firestore sync error: $e');
    }

    return count;
  }

  /// Pull Cloud Firestore Master Data and overwrite local SQLite DB (Anti-Tamper & Multi-User Isolation)
  Future<int> pullCloudFirestoreToLocal({bool isAccountSwitch = false}) async {
    final user = currentUser;
    if (user == null) return 0;

    final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
    int count = 0;

    try {
      final catSnap = await userDoc.collection('categories').get();
      final actSnap = await userDoc.collection('activity_logs').get();
      final lblSnap = await userDoc.collection('labels').get();

      if (isAccountSwitch) {
        await DatabaseHelper.instance.clearLocalUserData();
      }

      if (catSnap.docs.isNotEmpty || actSnap.docs.isNotEmpty || lblSnap.docs.isNotEmpty) {
        final cloudCategories = catSnap.docs.map((d) => d.data()).toList();
        final cloudActivities = actSnap.docs.map((d) => d.data()).toList();

        for (var doc in lblSnap.docs) {
          await DatabaseHelper.instance.insertLabel(ActivityCategoryLabel.fromMap(doc.data()));
        }

        final cloudData = {
          'categories': cloudCategories,
          'activity_logs': cloudActivities,
        };

        count = await DatabaseHelper.instance.importBackupData(cloudData);
      } else if (isAccountSwitch) {
        await syncFullFirestore();
      }
    } catch (e) {
      debugPrint('Firestore pull error: $e');
    }

    return count;
  }

  Future<void> deleteFirestoreActivity(String id) async {
    final user = currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('activity_logs')
          .doc(id)
          .delete();
    } catch (e) {
      debugPrint('Firestore delete activity error: $e');
    }
  }

  Future<void> deleteFirestoreCategory(String id) async {
    final user = currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('categories')
          .doc(id)
          .delete();
    } catch (e) {
      debugPrint('Firestore delete category error: $e');
    }
  }

  Future<void> deleteFirestoreLabel(String id) async {
    final user = currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('labels')
          .doc(id)
          .delete();
    } catch (e) {
      debugPrint('Firestore delete label error: $e');
    }
  }
}

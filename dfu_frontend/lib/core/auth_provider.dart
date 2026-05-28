import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum UserRole { admin, doctor, patient, unknown }

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _user;
  UserRole _role = UserRole.unknown;
  bool _isLoading = true;

  User? get user => _user;
  UserRole get role => _role;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    // Initialize SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    // Load cached role if available
    final cachedRole = prefs.getString('user_role');
    if (cachedRole != null) {
      _role = UserRole.values.firstWhere((e) => e.toString() == cachedRole, orElse: () => UserRole.unknown);
    }
    _auth.authStateChanges().listen((User? user) async {
      _user = user;
      if (user != null) {
        // If role not cached, fetch from Firestore
        await _fetchRole(user.uid);
        // Save fetched role
        await prefs.setString('user_role', _role.toString());
      } else {
        _role = UserRole.unknown;
        await prefs.remove('user_role');
      }
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> _fetchRole(String uid) async {
    // HARDCODE INTERCEPT FOR DOCTOR
    if (_user?.email == 'doctor1@gmail.com') {
      _role = UserRole.doctor;
      return;
    }

    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final roleStr = doc.data()?['role'] as String?;
        switch (roleStr) {
          case 'admin':
            _role = UserRole.admin;
            break;
          case 'doctor':
            _role = UserRole.doctor;
            break;
          case 'patient':
            _role = UserRole.patient;
            break;
          default:
            _role = UserRole.unknown;
        }
      } else {
        _role = UserRole.patient; // Default fallback
      }
    } catch (e) {
      _role = UserRole.unknown;
    }
  }

  Future<bool> signIn(String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return true;
    } catch (e) {
      print("Login Error: $e");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String email, String password, UserRole selectedRole) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      UserCredential cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      
      String roleString;
      switch (selectedRole) {
        case UserRole.admin: roleString = 'admin'; break;
        case UserRole.doctor: roleString = 'doctor'; break;
        case UserRole.patient: roleString = 'patient'; break;
        default: roleString = 'patient';
      }

      await _firestore.collection('users').doc(cred.user!.uid).set({
        'email': email,
        'role': roleString,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      return true;
    } catch (e) {
      print("Registration Error: $e");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}

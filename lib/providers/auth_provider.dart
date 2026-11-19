import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_constants.dart';
import '../models/user_model.dart';
import '../services/supabase_service.dart';

class AuthProvider with ChangeNotifier {
  UserModel _currentUser = UserModel(
    id: 1,
    username: 'admin',
    name: 'Cafe Manager',
    role: AppConstants.roleAdmin,
    pin: '1234',
  );

  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _errorMessage;

  AuthProvider() {
    _checkExistingSession();
  }

  UserModel get currentUser => _currentUser;
  String get activeRole => _currentUser.role;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get isAdmin => _currentUser.role == AppConstants.roleAdmin;
  bool get isCashier => _currentUser.role == AppConstants.roleCashier;
  bool get isManager => _currentUser.role == AppConstants.roleManager;

  /// Check if user is already logged in via Supabase session
  void _checkExistingSession() {
    final sbUser = SupabaseService.currentUser;
    if (sbUser != null) {
      _currentUser = SupabaseService.mapSupabaseUserToModel(sbUser);
      _isAuthenticated = true;
      notifyListeners();
    }
  }

  /// Login with Supabase credentials (email/username + password)
  Future<bool> loginWithSupabase({
    required String usernameOrEmail,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await SupabaseService.signIn(
        usernameOrEmail: usernameOrEmail,
        password: password,
      );

      if (response != null && response.user != null) {
        _currentUser = SupabaseService.mapSupabaseUserToModel(response.user!);
        _isAuthenticated = true;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Authentication failed. Please check credentials.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } on AuthException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Offline / Demo Bypass Login
  void loginBypassOffline({String username = 'admin'}) {
    _currentUser = UserModel(
      id: 1,
      username: username,
      name: username == 'admin' ? 'Cafe Manager' : username,
      role: AppConstants.roleAdmin,
      pin: '1234',
    );
    _isAuthenticated = true;
    _errorMessage = null;
    notifyListeners();
  }

  /// Logout user from Supabase and clear session
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await SupabaseService.signOut();
    } catch (e) {
      debugPrint('Logout error: $e');
    }

    _isAuthenticated = false;
    _isLoading = false;
    notifyListeners();
  }

  void switchRole(String newRole) {
    _currentUser = UserModel(
      id: _currentUser.id,
      username: _currentUser.username,
      name: _currentUser.name,
      role: newRole,
      pin: _currentUser.pin,
    );
    notifyListeners();
  }
}

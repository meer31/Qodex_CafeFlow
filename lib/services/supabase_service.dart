import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/supabase_constants.dart';
import '../models/user_model.dart';
import '../core/constants/app_constants.dart';

class SupabaseService {
  static bool _isInitialized = false;

  static bool get isInitialized => _isInitialized;

  /// Initializes Supabase client with safety handling
  static Future<void> initialize() async {
    try {
      if (SupabaseConstants.supabaseUrl.contains('xyzcompany') ||
          SupabaseConstants.supabaseAnonKey.contains('...')) {
        debugPrint('Supabase: Using placeholder credentials. Replace with actual credentials in SupabaseConstants.');
      }
      await Supabase.initialize(
        url: SupabaseConstants.supabaseUrl,
        anonKey: SupabaseConstants.supabaseAnonKey,
      );
      _isInitialized = true;
      debugPrint('Supabase initialized successfully.');
    } catch (e) {
      debugPrint('Supabase initialization warning: $e');
      _isInitialized = false;
    }
  }

  /// Helper to convert username input to valid email if needed
  static String formatEmail(String input) {
    final trimmed = input.trim();
    if (trimmed.contains('@')) {
      return trimmed;
    }
    return '$trimmed@${SupabaseConstants.defaultEmailDomain}';
  }

  /// Sign in user with Username/Email and Password via Supabase Auth
  static Future<AuthResponse?> signIn({
    required String usernameOrEmail,
    required String password,
  }) async {
    final email = formatEmail(usernameOrEmail);

    if (!_isInitialized) {
      throw Exception('Supabase is not initialized. Please check your Supabase URL and Anon Key in supabase_constants.dart.');
    }

    final response = await Supabase.instance.client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    return response;
  }

  /// Sign out current user
  static Future<void> signOut() async {
    if (_isInitialized) {
      await Supabase.instance.client.auth.signOut();
    }
  }

  /// Get current Supabase session
  static Session? get currentSession {
    if (!_isInitialized) return null;
    return Supabase.instance.client.auth.currentSession;
  }

  /// Get current Supabase user
  static User? get currentUser {
    if (!_isInitialized) return null;
    return Supabase.instance.client.auth.currentUser;
  }

  /// Map Supabase User object into CafeFlow UserModel
  static UserModel mapSupabaseUserToModel(User user) {
    final metadata = user.userMetadata ?? {};
    final email = user.email ?? 'admin@cafeflow.com';
    final username = email.contains('@') ? email.split('@').first : email;
    final name = metadata['name'] as String? ?? metadata['full_name'] as String? ?? username.toUpperCase();
    final role = metadata['role'] as String? ?? AppConstants.roleAdmin;

    return UserModel(
      id: 1,
      username: username,
      name: name,
      role: role,
      pin: '0000',
    );
  }
}

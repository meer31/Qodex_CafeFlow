class SupabaseConstants {
  /// REPLACE THESE WITH YOUR SUPABASE PROJECT URL AND ANON KEY FROM SUPABASE DASHBOARD:
  /// Supabase Dashboard -> Project Settings -> API -> Project URL & anon / public key
  static const String supabaseUrl = 'https://quahabarjvlekzbjbgoq.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF1YWhhYmFyanZsZWt6YmpiZ29xIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg0ODc5NDgsImV4cCI6MjA4NDA2Mzk0OH0.Fzh3rlT-Tb5apqUXxJ-EMZxtwXBqu7rmacWLeLvehLo';

  /// Default domain appended if user enters plain username instead of full email (e.g. 'admin' -> 'admin@cafeflow.com')
  static const String defaultEmailDomain = 'cafeflow.com';
}

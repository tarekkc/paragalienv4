class SupabaseConstants {
  // Replace with your Supabase project credentials
  static const String url = 'https://kvchiulgsvgzvzqfeakp.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt2Y2hpdWxnc3ZnenZ6cWZlYWtwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDU2ODI3NDgsImV4cCI6MjA2MTI1ODc0OH0.nLBRHt0NICsMYQBqWhXbcjUiwwFqT6gJ8R0cJ_GvGkc';
   static const String appDeepLink = 'paragalien'; // Your app's unique scheme
  // Table names (match your Supabase setup)
  static const String productsTable = 'produits';
  static const String ordersTable = 'commandes';
  static const String orderItemsTable = 'commande_items';
  static const String profilesTable = 'profiles';
  
}

class AppConstants {
  // App styling
  static const double defaultPadding = 16.0;
  static const double borderRadius = 12.0;
  static const String appScheme = 'paragalien';

  // Default error messages
  static const String genericError = 'Something went wrong!';
  static const String noInternetError = 'No internet connection';
  static const String loginHint = '';
  static const String passwordResetHint = 'Contact admin for password reset';
  static const String defaultAdminEmail = 'admin@paralien.com';
}
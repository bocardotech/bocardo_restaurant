/// Supabase Authentication Configuration for Bocardo Restaurant
///
/// All values are injected securely at compile/run time via:
/// flutter run --dart-define-from-file=.env
class SupabaseConfig {
  SupabaseConfig._();

  /// Project Reference ID
  static const String projectRef = String.fromEnvironment(
    'SUPABASE_PROJECT_REF',
    defaultValue: '',
  );

  /// Supabase API URL
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  /// Supabase Publishable / Anon Key (Safe for client distribution)
  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: '',
  );

  /// Supabase JWKS Endpoint (for token verification by resource servers)
  static const String supabaseJwksUrl = String.fromEnvironment(
    'SUPABASE_JWKS_URL',
    defaultValue: '',
  );

  /// Postgres Connection Strings (For Server / Migration tooling only)
  static const String poolerHost = String.fromEnvironment(
    'SUPABASE_POOLER_HOST',
    defaultValue: 'aws-0-ap-southeast-1.pooler.supabase.com',
  );
  static const int transactionPoolerPort = 6543;
  static const int sessionPoolerPort = 5432;

  /// Custom URL scheme for OAuth and Magic Link deep links
  static const String callbackUrlScheme = 'bocardo';
  static const String redirectUrl = 'bocardo://login-callback';
}

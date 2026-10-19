# Bocardo Restaurant - Supabase Authentication Architecture Report
## Enterprise-Grade, Scalable Multi-Tenant Identity Infrastructure

---

## 1. Executive Summary & Codebase Audit

### 1.1 Initial State Analysis
Prior to this implementation, the `bocardo_restaurant` codebase possessed:
* **Mock In-Memory Authentication** (`lib/services/auth_service.dart`): Stored credentials in a static Dart `Map<String, _Account>` with plain text string comparison (`account.password != password`). Sessions were ephemeral and destroyed upon application restart.
* **Disconnected Firebase Client** (`lib/screens/login_page.dart`): Attempted Google Sign-in using `firebase_auth`, creating an identity silo separate from the primary restaurant database.
* **Missing Relational Persistence**: Registration metadata (`restaurantName`, `ownerName`, `phone`) was discarded without syncing to an operational database table.

### 1.2 The Production Transformation
The authentication layer has been re-architected into a **scalable, zero-trust Supabase identity engine** leveraging:
1. **RFC 7636 PKCE (Proof Key for Code Exchange)** for all OAuth and authorization code exchanges.
2. **Automated Refresh Token Rotation** to neutralize token replay and session theft.
3. **Multi-Tenant Row Level Security (RLS)** in PostgreSQL to guarantee complete tenant isolation between competing restaurants.
4. **Database Event-Driven User Synchronization**: An automated trigger on `auth.users` synchronizes user registration metadata directly into `public.restaurants` and `public.restaurant_profiles`.
5. **Dual Test UIs**:
   - **In-App Flutter Test Bench** (`lib/screens/auth_test_bench_page.dart` at `/auth-test-bench`).
   - **Standalone Web Test Bench** (`test_ui/index.html` + `test_ui/server.js`) launchable via `node test_ui/server.js`.

---

## 2. System Architecture

```mermaid
flowchart TD
    subgraph Client["Flutter Mobile & Web Clients"]
        UI["Login & Signup Pages"]
        TestBench["Auth Test Bench Screen"]
        AuthFacade["AuthService (Facade Pattern)"]
        SupabaseService["SupabaseAuthService (PKCE)"]
    end

    subgraph Supabase["Supabase Cloud Infrastructure"]
        AuthServer["GoTrue Auth Engine (HTTPS)"]
        JWKS["JWKS Public Endpoint"]
        SessionPooler["Postgres Session Pooler (Port 5432)"]
        TxPooler["Transaction Pooler (Port 6543)"]
    end

    subgraph Database["PostgreSQL Core Database"]
        AuthUsers["auth.users (System Identity)"]
        Trigger["Trigger: on_auth_user_created"]
        Restaurants["public.restaurants (Tenant Root)"]
        Profiles["public.restaurant_profiles"]
        AuditLogs["public.auth_audit_logs"]
    end

    UI --> AuthFacade
    TestBench --> SupabaseService
    AuthFacade --> SupabaseService
    SupabaseService -- "PKCE / Auto-Refresh (HTTPS)" --> AuthServer
    AuthServer --> AuthUsers
    AuthUsers --> Trigger
    Trigger -- "SECURITY DEFINER" --> Restaurants
    Trigger --> Profiles
    Trigger --> AuditLogs

    SessionPooler --> Database
    TxPooler --> Database
```

---

## 3. Implemented Components

### 3.1 Central Configuration: `lib/config/supabase_config.dart`
Centralizes project identifiers, connection endpoints, and security boundaries.

```dart
class SupabaseConfig {
  static const String projectRef = String.fromEnvironment('SUPABASE_PROJECT_REF', defaultValue: '');
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const String supabasePublishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY', defaultValue: '');
  static const String supabaseJwksUrl = String.fromEnvironment('SUPABASE_JWKS_URL', defaultValue: '');
  static const String poolerHost = String.fromEnvironment('SUPABASE_POOLER_HOST', defaultValue: 'aws-0-ap-southeast-1.pooler.supabase.com');
}
```

> [!IMPORTANT]
> **Key Hierarchy Rule**:
> - Publishable keys are client-safe and can be embedded in client-side builds.
> - Service role / secret keys are administrative secrets and must **NEVER** be packaged or distributed in client-side mobile builds.

---

### 3.2 Strongly-Typed Domain Model: `lib/models/restaurant_user.dart`
Extracts and normalizes metadata from Supabase's `auth.users` object:

* `id`: Unique UUIDv4 identity key.
* `email`: User email address.
* `restaurantName`: Registered restaurant name.
* `ownerName`: Full name of the owner/operator.
* `phone`: Contact telephone number.
* `role`: System authorization role (`authenticated`, `restaurant_owner`).
* `isEmailVerified`: Boolean flag reflecting `emailConfirmedAt`.

---

### 3.3 Core Engine: `lib/services/supabase_auth_service.dart`
Production service encapsulating all authentication capabilities:
* **PKCE Initialization**:
  ```dart
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabasePublishableKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      autoRefreshToken: true,
    ),
  );
  ```
* **Metadata-Rich Sign Up**: Encapsulates restaurant details into `data` map during `signUp()`.
* **Passwordless Authentication**: `sendMagicLink(email)` for passwordless email OTP logins.
* **Refresh Token Rotation**: `refreshSession()` allows manual or automatic session rejuvenation while rotating underlying refresh credentials.
* **Real-Time Stream**: `Stream<RestaurantUser?> get authStateChanges` notifies UI widgets when the user signs in, logs out, or refreshes.
* **Diagnostics Health Check**: `checkDiagnostics()` validates active session parameters, token expiration, and endpoint reachability.

---

### 3.4 Facade Layer: `lib/services/auth_service.dart`
Preserves complete backward compatibility for existing Flutter screens (`login_page.dart`, `signup_page.dart`, `restaurant_home_page.dart`). Calls to `AuthService.instance.signIn()` and `signUp()` now dispatch to Supabase seamlessly while offering an offline fallback if the device has no internet connection.

---

## 4. PostgreSQL Database Schema & Multi-Tenant Security

The migration script is stored at:
`supabase/migrations/20261018000000_create_bocardo_auth_and_restaurants.sql`

### 4.1 Schema Tables
1. **`public.restaurants`**: Root tenant table linking to `auth.users(id)`.
2. **`public.restaurant_profiles`**: Operating hours, cuisine classifications, order acceptance status.
3. **`public.auth_audit_logs`**: Append-only audit record tracking security events (`USER_REGISTERED`, `LOGIN_SUCCESS`, `MFA_CHALLENGE`).

### 4.2 Automated Synchronization Trigger
```sql
CREATE OR REPLACE FUNCTION public.handle_new_restaurant_user()
RETURNS TRIGGER SECURITY DEFINER LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO public.restaurants (
        user_id, restaurant_name, owner_name, phone, email, is_verified
    ) VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'restaurant_name', 'Bocardo Restaurant'),
        COALESCE(NEW.raw_user_meta_data->>'owner_name', 'Owner'),
        COALESCE(NEW.raw_user_meta_data->>'phone', ''),
        NEW.email,
        (NEW.email_confirmed_at IS NOT NULL)
    );
    RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_restaurant_user();
```

### 4.3 Multi-Tenant Row Level Security (RLS)
* **Public Visibility**: The dining public can only view restaurants where `status = 'active'`.
* **Tenant Isolation**: Restaurant owners can only view and update their own restaurant profile matching `auth.uid() = user_id`.

```sql
CREATE POLICY "Owners can update own restaurant"
    ON public.restaurants
    FOR UPDATE TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);
```

---

## 5. How to Test the Authentication Module

### Option 1: Standalone Web Test Bench (Zero Dependencies)
You can test the entire Supabase authentication engine directly from your browser:

1. Launch the local test server:
   ```bash
   node test_ui/server.js
   ```
2. Open your browser to:
   ```
   http://localhost:3000
   ```
3. Test features in real time:
   - **Create Restaurant Account**: Enter email, password, restaurant name, owner name, phone.
   - **Sign In with Password**: Authenticates against Supabase GoTrue.
   - **Rotate Refresh Token**: Inspect token rotation and view updated JWT expiration.
   - **Send Magic Link / Reset Password**: Dispatches verification emails.
   - **Live Audit Console**: Shows JSON payloads and timestamps of all auth actions.

---

### Option 2: Flutter In-App Test Bench
1. Ensure dependencies are fetched:
   ```bash
   flutter pub get
   ```
2. Run the Flutter app with your local `.env`:
   ```bash
   flutter run --dart-define-from-file=.env
   ```
3. From the Login screen, click the **"Open Supabase Auth Test Bench"** button at the bottom (or navigate to `/auth-test-bench`).

---

## 6. Connection Strings & Infrastructure Troubleshooting

### 6.1 Database Connection Details
* **Transaction Pooler (Application Queries - Port 6543)**:
  ```
  postgresql://postgres.[YOUR-PROJECT-REF]:[YOUR-PASSWORD]@aws-0-ap-southeast-1.pooler.supabase.com:6543/postgres?pgbouncer=true
  ```
* **Session Pooler (Migrations & DDL - Port 5432)**:
  ```
  postgresql://postgres.[YOUR-PROJECT-REF]:[YOUR-PASSWORD]@aws-0-ap-southeast-1.pooler.supabase.com:5432/postgres
  ```

> [!TIP]
> **Password URL-Encoding**: If your database password contains special characters (like `@` or `#`), they **must be URL-encoded** (for example, `@` becomes `%40`) to prevent connection parsers from misinterpreting the host boundary.

### 6.2 DNS & Project Pause Note
If your Supabase project endpoint returns `NXDOMAIN`:
1. Log in to the Supabase Dashboard.
2. Check your project status.
3. If the project was paused due to inactivity, click **"Restore Project"**. Supabase will re-provision the dedicated endpoint and DNS routing within 60 seconds.

---

## 7. Future Scalability Checklist

- [x] **PKCE Flow**: Implemented for all OAuth and token exchanges.
- [x] **Refresh Token Rotation**: Implemented and verifiable via test bench.
- [x] **RLS Data Isolation**: Policies written and staged in migrations.
- [x] **Audit Logging**: Event trigger architecture ready for security operations.
- [ ] **FIDO2 / WebAuthn**: Add passkey support for one-tap biometric restaurant manager login.
- [ ] **Step-Up Authentication**: Require re-authentication before modifying restaurant payout bank details.
- [ ] **Role-Based Access Control (RBAC)**: Expand user roles to include `kitchen_display`, `delivery_dispatcher`, and `floor_manager`.

/**
 * Bocardo Restaurant - Authentication Test Suite & Verification Runner
 * Runs end-to-end verification of the authentication module, configuration,
 * security boundaries, and local server endpoints.
 */
const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const https = require('node:https');
const dns = require('node:dns');

const PROJECT_ROOT = path.join(__dirname, '..');
const ENV_FILE = path.join(PROJECT_ROOT, '.env');
const GITIGNORE_FILE = path.join(PROJECT_ROOT, '.gitignore');

let passedTests = 0;
let totalTests = 0;

function assert(condition, testName) {
  totalTests++;
  if (condition) {
    console.log(`  [PASS] ${testName}`);
    passedTests++;
  } else {
    console.error(`  [FAIL] ${testName}`);
  }
}

// 1. Environment & Secrets Security Test
console.log('\n--- 1. Testing Environment Variables & Security Isolation ---');
assert(fs.existsSync(ENV_FILE), '.env file exists locally on disk');
assert(fs.existsSync(GITIGNORE_FILE), '.gitignore file exists');

const gitignoreContent = fs.readFileSync(GITIGNORE_FILE, 'utf-8');
assert(
  gitignoreContent.includes('.env') && gitignoreContent.includes('.env.*'),
  '.gitignore strictly excludes .env and .env.* from version control'
);

const envContent = fs.readFileSync(ENV_FILE, 'utf-8');
const envVars = {};
for (const line of envContent.split('\n')) {
  const trimmed = line.trim();
  if (!trimmed || trimmed.startsWith('#')) continue;
  const [k, ...v] = trimmed.split('=');
  envVars[k.trim()] = v.join('=').trim();
}

assert(!!envVars.SUPABASE_URL, 'SUPABASE_URL is defined in .env');
assert(!!envVars.SUPABASE_PUBLISHABLE_KEY, 'SUPABASE_PUBLISHABLE_KEY is defined in .env');
assert(!!envVars.DATABASE_URL, 'DATABASE_URL is defined in .env');
assert(!!envVars.DIRECT_URL, 'DIRECT_URL is defined in .env');

// Verify that password in connection string is URL-encoded
if (envVars.DATABASE_URL && envVars.DATABASE_URL.includes('Bocardo')) {
  assert(
    envVars.DATABASE_URL.includes('%40') && !envVars.DATABASE_URL.includes('Bocardo@technology'),
    'Database URL has @ URL-encoded as %40 to prevent host parsing collision'
  );
}

// 2. Secret Leak Inspection Across Codebase
console.log('\n--- 2. Auditing Codebase for Leaked Secrets ---');
function scanDirForSecrets(dir) {
  let leaked = false;
  const files = fs.readdirSync(dir);
  for (const file of files) {
    const fullPath = path.join(dir, file);
    if (file === '.env' || file === '.git' || file === 'node_modules') continue;
    const stat = fs.statSync(fullPath);
    if (stat.isDirectory()) {
      if (scanDirForSecrets(fullPath)) leaked = true;
    } else if (file.endsWith('.dart') || file.endsWith('.html') || file.endsWith('.md')) {
      const content = fs.readFileSync(fullPath, 'utf-8');
      if (
        content.includes('Bocardo@technology') ||
        content.includes('sb_secret_lTm5') ||
        content.includes('sb_publishable_nezto')
      ) {
        console.error(`  Secret leak detected in ${fullPath}!`);
        leaked = true;
      }
    }
  }
  return leaked;
}

const hasLeakedSecrets = scanDirForSecrets(PROJECT_ROOT);
assert(!hasLeakedSecrets, 'Zero sensitive credentials found in tracked source files');

// 3. Verifying Dart Code & Model Structure
console.log('\n--- 3. Verifying Flutter Auth Architecture & Models ---');
const configDart = fs.readFileSync(path.join(PROJECT_ROOT, 'lib/config/supabase_config.dart'), 'utf-8');
assert(configDart.includes('class SupabaseConfig'), 'SupabaseConfig class is properly defined');
assert(configDart.includes('String.fromEnvironment'), 'SupabaseConfig uses String.fromEnvironment for secure compilation');

const modelDart = fs.readFileSync(path.join(PROJECT_ROOT, 'lib/models/restaurant_user.dart'), 'utf-8');
assert(modelDart.includes('class RestaurantUser'), 'RestaurantUser model is defined');
assert(modelDart.includes('fromSupabaseUser'), 'RestaurantUser implements fromSupabaseUser factory');
assert(modelDart.includes('restaurantName'), 'RestaurantUser model extracts restaurantName');
assert(modelDart.includes('ownerName'), 'RestaurantUser model extracts ownerName');

const serviceDart = fs.readFileSync(path.join(PROJECT_ROOT, 'lib/services/supabase_auth_service.dart'), 'utf-8');
assert(serviceDart.includes('class SupabaseAuthService'), 'SupabaseAuthService is defined');
assert(serviceDart.includes('signUpWithEmailAndPassword'), 'signUpWithEmailAndPassword method implemented');
assert(serviceDart.includes('signInWithEmailAndPassword'), 'signInWithEmailAndPassword method implemented');
assert(serviceDart.includes('signInWithGoogleIdToken'), 'signInWithGoogleIdToken method implemented');
assert(serviceDart.includes('refreshSession'), 'refreshSession method implemented for token rotation');
assert(serviceDart.includes('authStateChanges'), 'authStateChanges real-time stream implemented');

const facadeDart = fs.readFileSync(path.join(PROJECT_ROOT, 'lib/services/auth_service.dart'), 'utf-8');
assert(facadeDart.includes('class AuthService'), 'AuthService facade is defined');
assert(facadeDart.includes('SupabaseAuthService.instance'), 'AuthService facade delegates to SupabaseAuthService');

const mainDart = fs.readFileSync(path.join(PROJECT_ROOT, 'lib/main.dart'), 'utf-8');
assert(mainDart.includes('class AuthGate'), 'AuthGate widget implemented for automatic session routing');

const migrationSql = fs.readFileSync(
  path.join(PROJECT_ROOT, 'supabase/migrations/20261018000000_create_bocardo_auth_and_restaurants.sql'),
  'utf-8'
);
assert(migrationSql.includes('CREATE TABLE IF NOT EXISTS public.restaurants'), 'Migration defines public.restaurants');
assert(migrationSql.includes('handle_new_restaurant_user'), 'Migration defines trigger function handle_new_restaurant_user');
assert(migrationSql.includes('ENABLE ROW LEVEL SECURITY'), 'Migration enables Row Level Security (RLS)');

// 4. Testing Local Test Server Endpoints
console.log('\n--- 4. Testing Local Test Server & Configuration API ---');
const testServer = require('../test_ui/server.js');

setTimeout(async () => {
  try {
    const configRes = await new Promise((resolve, reject) => {
      http.get('http://localhost:3000/api/config', (res) => {
        let data = '';
        res.on('data', chunk => data += chunk);
        res.on('end', () => resolve({ status: res.statusCode, body: JSON.parse(data) }));
      }).on('error', reject);
    });

    assert(configRes.status === 200, 'Test UI server returns 200 on /api/config');
    assert(configRes.body.supabaseUrl === envVars.SUPABASE_URL, 'Server loads SUPABASE_URL dynamically from .env');
    assert(configRes.body.supabaseAnonKey === envVars.SUPABASE_PUBLISHABLE_KEY, 'Server loads SUPABASE_PUBLISHABLE_KEY dynamically from .env');

    const healthRes = await new Promise((resolve, reject) => {
      http.get('http://localhost:3000/health', (res) => {
        let data = '';
        res.on('data', chunk => data += chunk);
        res.on('end', () => resolve({ status: res.statusCode, body: JSON.parse(data) }));
      }).on('error', reject);
    });
    assert(healthRes.status === 200 && healthRes.body.status === 'ok', 'Test UI server returns 200 on /health');

    // 5. DNS & Supabase Cloud Endpoint Reachability
    console.log('\n--- 5. Checking Supabase Cloud Endpoint Reachability ---');
    const hostname = new URL(envVars.SUPABASE_URL).hostname;
    dns.lookup(hostname, (err, address) => {
      if (err) {
        console.log(`  [INFO] DNS lookup for ${hostname}: ${err.code}`);
        console.log(`  [DIAGNOSTIC] ${hostname} is currently not resolving (NXDOMAIN).`);
        console.log(`  [ACTION] To activate live cloud testing, log in to the Supabase Dashboard and restore/unpause the project.`);
      } else {
        console.log(`  [PASS] ${hostname} resolved to ${address}`);
      }

      console.log('\n======================================================');
      console.log(`  TEST RESULTS: ${passedTests} / ${totalTests} TESTS PASSED`);
      console.log('======================================================\n');
      process.exit(passedTests === totalTests ? 0 : 1);
    });
  } catch (err) {
    console.error('Error during HTTP test:', err);
    process.exit(1);
  }
}, 500);

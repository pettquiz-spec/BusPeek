import 'package:latlong2/latlong.dart';

// ================= YOUR SETTINGS =================
// Keep this file in lib/ next to main.dart.
// When main.dart is updated, this file stays the same,
// so you never have to paste your keys again.

// Supabase > Project Settings > API
const String kSupabaseUrl = 'https://jrsbpwyiysffxlixyten.supabase.co';
// the publishable (anon) key is made for apps. NEVER put the secret key here.
const String kSupabaseAnonKey = 'sb_publishable_ql00CAVpSc-axesKdoLohg_yIRrYQs-';

// Map start (between Tandag, Butuan and Davao)
const LatLng kCenter = LatLng(8.15, 125.85);
const double kZoom = 8;

const Duration kRefresh = Duration(seconds: 3);
const int kSeats = 40; // 10 rows x 4 seats
const int kStaleSeconds = 120; // no GPS for 2 min = not running

// ----- AI helper -----
// Leave kClaudeKey empty = "offline mode" (simple answers from the bus list).
// WARNING: a key inside an app can be stolen. Testing only, never publish
// the app with the key inside. Later, use a backend.
const String kClaudeKey = '';
const String kModel = 'claude-sonnet-5-5';

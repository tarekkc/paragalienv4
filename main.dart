import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'core/constants.dart';
import 'core/routs.dart';
import 'package:paragalien/views/auth/login_screen.dart';
import 'package:paragalien/views/admin/admin_home.dart';
import 'package:paragalien/views/client/client_home.dart';
import 'providers/auth_provider.dart';

enum AppTheme { light, dark }

// Add connectivity provider
final connectivityProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();

  // Check initial state
  final initialResult = await connectivity.checkConnectivity();
  yield initialResult != ConnectivityResult.none;

  // Listen for changes
  await for (final result in connectivity.onConnectivityChanged) {
    yield result != ConnectivityResult.none;
  }
});

final themeProvider = StateNotifierProvider<ThemeNotifier, AppTheme>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<AppTheme> {
 ThemeNotifier() : super(AppTheme.dark)  {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
     final isDark = prefs.getBool('isDark') ?? true;
    state = isDark ? AppTheme.dark : AppTheme.light;
  }

  Future<void> toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    if (state == AppTheme.light) {
      state = AppTheme.dark;
      await prefs.setBool('isDark', true);
    } else {
      state = AppTheme.light;
      await prefs.setBool('isDark', false);
    }
  }
}

final lightTheme = ThemeData(
  primarySwatch: Colors.blue,
  brightness: Brightness.light,
  scaffoldBackgroundColor: Colors.white,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.blue,
    foregroundColor: Colors.white,
  ),
);

final darkTheme = ThemeData(
  primarySwatch: Colors.blue,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: Colors.grey[900],
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.grey[850],
    foregroundColor: Colors.white,
  ),
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize connectivity first
  try {
    final connectivity = Connectivity();
    await connectivity.checkConnectivity(); // This initializes the plugin
  } catch (e) {
    debugPrint('Connectivity initialization error: $e');
  }

  // Then initialize other plugins
  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  OneSignal.initialize('f80cbfd0-124d-4dca-bc2e-e4f021b8a872');
  OneSignal.Notifications.requestPermission(true);

  await Supabase.initialize(
    url: SupabaseConstants.url,
    anonKey: SupabaseConstants.anonKey,
  );

  runApp(const ProviderScope(child: ConnectivityWrapper()));
}

// New wrapper widget for connectivity
class ConnectivityWrapper extends ConsumerWidget {
  const ConnectivityWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(connectivityProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      home: connectivity.when(
        loading:
            () => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
        error:
            (error, _) => Scaffold(
              body: Center(child: Text('Error checking connectivity: $error')),
            ),
        data:
            (isConnected) =>
                isConnected ? const MyApp() : const OfflineScreen(),
      ),
    );
  }
}

class OfflineScreen extends StatelessWidget {
  const OfflineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.signal_wifi_off, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Vous êtes hors ligne',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Veuillez vérifier votre connexion internet',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                // This will trigger a rebuild when connection returns
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const MyApp()),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final currentTheme = ref.watch(themeProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode:
          currentTheme == AppTheme.light ? ThemeMode.light : ThemeMode.dark,
      home: authState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data:
            (session) =>
                session == null
                    ? const LoginScreen()
                    : _getRoleBasedHome(ref, session.user.id),
      ),
      onGenerateRoute: AppRoutes.generateRoute,
    );
  }

  Widget _getRoleBasedHome(WidgetRef ref, String userId) {
    final role = ref.watch(userRoleProvider(userId));
    return role.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (role) => role == 'admin' ? const AdminHome() : const ClientHome(),
    );
  }
}

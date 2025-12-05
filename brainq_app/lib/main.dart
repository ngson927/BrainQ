import 'package:brainq_app/api_helper.dart';
import 'package:brainq_app/providers/admin_provider.dart';
import 'package:brainq_app/screens/dashboard/admin_dashboard_screen.dart';
import 'package:brainq_app/services/api_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

// Providers
import 'providers/auth_provider.dart';
import 'providers/deck_provider.dart';
import 'providers/theme_provider.dart';
import 'config/theme.dart';

// Screens
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/dashboard/notifications_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/dashboard/reminders_screen.dart';

// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';

// Notification service
import 'services/notification_service.dart';

// Navigator Key
final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

// --------------------------------------------------
// Background message handler
// --------------------------------------------------
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!kIsWeb) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  if (message.notification != null) {
    final reminderId = int.tryParse(message.data['reminder_id'] ?? '') ?? DateTime.now().millisecondsSinceEpoch.remainder(1000000);

    await NotificationService.instance.showNotification(
      id: reminderId,
      title: message.notification!.title ?? '',
      body: message.notification!.body ?? '',
      payload: reminderId.toString(),
    );
  }
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await NotificationService.instance.init();

  runApp(const BrainQBootstrap());
}

// --------------------------------------------------
// Bootstrap — UI runs AFTER services initialized
// --------------------------------------------------
class BrainQBootstrap extends StatefulWidget {
  const BrainQBootstrap({super.key});

  @override
  State<BrainQBootstrap> createState() => _BrainQBootstrapState();
}

class _BrainQBootstrapState extends State<BrainQBootstrap> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = _createRouter();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    // Link navigator for payload taps
    NotificationService.instance.navigatorKey = _navigatorKey;

    // Request FCM permissions (foreground only)
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();

    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      if (message.notification != null) {
        final reminderId = int.tryParse(message.data['reminder_id'] ?? '') ?? DateTime.now().millisecondsSinceEpoch.remainder(1000000);

        await NotificationService.instance.showNotification(
          id: reminderId,
          title: message.notification!.title ?? '',
          body: message.notification!.body ?? '',
          payload: reminderId.toString(),
        );
      }
    });


    // Token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      final authToken = await ApiHelper.getAuthToken();
      if (authToken != null) {
        await ApiService.registerDeviceToken(
          token: newToken,
          authToken: authToken,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DeckProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(
          create: (context) => AdminProvider(
            authProvider: Provider.of<AuthProvider>(context, listen: false),
          ),
        ),
      ],
      child: BrainQApp(router: _router),
    );
  }
}

// --------------------------------------------------
// Router Setup
// --------------------------------------------------
GoRouter _createRouter() {
  return GoRouter(
    navigatorKey: _navigatorKey,
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const LoginScreen()),

      // Regular user dashboard
      GoRoute(
        path: '/dashboard',
        builder: (_, _) => const DashboardScreen(),
        redirect: (context, state) {
          final authProvider = Provider.of<AuthProvider>(_navigatorKey.currentContext!, listen: false);

          if (!authProvider.isLoggedIn) return '/';          // Not logged in -> go to login
          if (authProvider.isAdmin) return '/admin/dashboard'; // Admin -> go to admin dashboard
          return null; // Regular user -> allow access
        },
      ),

      // Admin dashboard
      GoRoute(
        path: '/admin/dashboard',
        builder: (_, _) => const AdminDashboardScreen(),
        redirect: (context, state) {
          final authProvider = Provider.of<AuthProvider>(_navigatorKey.currentContext!, listen: false);

          if (!authProvider.isLoggedIn) return '/'; // Not logged in -> go to login
          if (!authProvider.isAdmin) return '/dashboard'; // Non-admin -> redirect to regular dashboard
          return null; // Admin -> allow access
        },
      ),

      // Auth routes
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/forgot-password', builder: (_, _) => const ForgotPasswordScreen()),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) {
          final token = state.uri.queryParameters['token'] ?? '';
          return ResetPasswordScreen(token: token);
        },
      ),

      // Other screens
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(path: '/reminders', builder: (_, _) => const ReminderScreen()),
      GoRoute(path: '/notifications', builder: (_, _) => const NotificationScreen()),
    ],
  );
}


// --------------------------------------------------
// App Wrapper
// --------------------------------------------------
class BrainQApp extends StatelessWidget {
  final GoRouter router;
  const BrainQApp({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (_, themeProvider, _) {
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: 'BrainQ',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.currentTheme,
          routerConfig: router,
        );
      },
    );
  }
}

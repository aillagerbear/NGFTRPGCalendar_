import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'screens/calendar_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/login_screen.dart';
import 'screens/shared_calendar_screen.dart';
import 'screens/loading_screen.dart';
import 'theme.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/route_service.dart';
import 'services/notification_service.dart';

final GoogleSignIn googleSignIn = GoogleSignIn();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  developer.log('Starting app initialization', name: 'main');

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    developer.log('Firebase initialized successfully', name: 'main');

    if (!kIsWeb) {
      // Initialize MobileAds only for mobile platforms
      await MobileAds.instance.initialize();
      developer.log('MobileAds initialized successfully', name: 'main');
    }

    // Initialize NotificationService
    final notificationService = NotificationService();
    await notificationService.initialize();
    developer.log('NotificationService initialized successfully', name: 'main');

    // Check battery optimization
    bool isBatteryOptimized = await notificationService.isBatteryOptimizationDisabled();
    developer.log('Battery optimization disabled: $isBatteryOptimized', name: 'main');

    // Register FCM token
    await notificationService.registerFCMToken();
    developer.log('FCM token registered', name: 'main');

  } catch (e) {
    developer.log('Error during initialization: $e', name: 'main', error: e);
  }

  developer.log('Running app', name: 'main');
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final NotificationService _notificationService = NotificationService();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        Provider(create: (_) => RouteService()),
        Provider.value(value: _notificationService),
      ],
      child: MaterialApp(
        title: 'TRPG Session Planner',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: FutureBuilder(
          future: _notificationService.initialize(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return AppWithTheme();
            }
            return LoadingScreen();
          },
        ),
      ),
    );
  }
}

class AppWithTheme extends StatefulWidget {
  @override
  _AppWithThemeState createState() => _AppWithThemeState();
}

class _AppWithThemeState extends State<AppWithTheme> {
  ThemeMode _themeMode = ThemeMode.system;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  _loadThemeMode() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _themeMode = ThemeMode.values[prefs.getInt('themeMode') ?? ThemeMode.system.index];
      _isLoading = false;
    });
  }

  _setThemeMode(ThemeMode themeMode) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _themeMode = themeMode;
    });
    await prefs.setInt('themeMode', themeMode.index);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TRPG Session Planner',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      home: _isLoading ? LoadingScreen() : InitialRouter(toggleTheme: _setThemeMode, currentThemeMode: _themeMode),
      routes: {
        '/login': (context) => LoginScreen(),
        '/main': (context) => MainScreen(toggleTheme: _setThemeMode, currentThemeMode: _themeMode),
      },
    );
  }
}

class InitialRouter extends StatefulWidget {
  final Function(ThemeMode) toggleTheme;
  final ThemeMode currentThemeMode;

  InitialRouter({required this.toggleTheme, required this.currentThemeMode});

  @override
  _InitialRouterState createState() => _InitialRouterState();
}

class _InitialRouterState extends State<InitialRouter> {
  late Future<String> _routeFuture;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialRoute();
  }

  void _loadInitialRoute() async {
    setState(() => _isLoading = true);
    final routeService = Provider.of<RouteService>(context, listen: false);
    _routeFuture = routeService.determineInitialRoute();
    await _routeFuture;
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    if (_isLoading) {
      return LoadingScreen();
    }

    return FutureBuilder<String>(
      future: _routeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return LoadingScreen();
        }

        if (snapshot.data?.startsWith('/shared/') ?? false) {
          final userId = snapshot.data!.split('/').last;
          return SharedCalendarScreen(
            userId: userId,
            toggleTheme: widget.toggleTheme,
            themeMode: widget.currentThemeMode,
          );
        } else {
          return StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return LoadingScreen();
              } else if (snapshot.hasData) {
                if (snapshot.data!.isAnonymous) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    Navigator.of(context).pushReplacementNamed('/login');
                  });
                  return LoadingScreen();
                } else {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    Navigator.of(context).pushReplacementNamed('/main');
                  });
                  return LoadingScreen();
                }
              } else {
                return LoginScreen();
              }
            },
          );
        }
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  final Function(ThemeMode) toggleTheme;
  final ThemeMode currentThemeMode;

  MainScreen({required this.toggleTheme, required this.currentThemeMode});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  bool _isLoading = false;

  void _handleLogout(BuildContext context) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    setState(() => _isLoading = true);
    await authService.signOut();
    setState(() => _isLoading = false);
    Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _screens = [
      CalendarScreen(),
      SettingsScreen(
        themeMode: widget.currentThemeMode,
        toggleTheme: widget.toggleTheme,
        logout: () => _handleLogout(context),
      ),
    ];

    if (_isLoading) {
      return LoadingScreen();
    }

    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: '캘린더',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: '설정',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/app_repository.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Portrait-only: the game's layout (letter wheel, timers, board) is designed
  // for a tall 9:16 screen and looks broken in landscape, so lock the rotation.
  SystemChrome.setPreferredOrientations(
      const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  runApp(const SpeedBeeApp());
}

class SpeedBeeApp extends StatelessWidget {
  const SpeedBeeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Word Sprint',
          debugShowCheckedModeBanner: false,
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          themeMode: mode,
          // Respect the OS text-size setting, but cap it: the game's custom
          // layouts (letter bubbles, milestone tiles) break at the largest
          // Dynamic Type sizes, so clamp scaling to a moderate maximum.
          builder: (context, child) {
            // Sync the brightness-aware BeeColors getters to the active theme
            // before any descendant builds this frame.
            BeeColors.brightness = Theme.of(context).brightness;
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(
                textScaler: mq.textScaler.clamp(
                  minScaleFactor: 1.0,
                  maxScaleFactor: 1.15,
                ),
              ),
              child: child!,
            );
          },
          home: const _Bootstrap(),
        );
      },
    );
  }
}

/// Loads the dictionary + stores once, showing a splash until ready.
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> with WidgetsBindingObserver {
  late final Future<AppRepository> _future;
  AppRepository? _repo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _future = AppRepository.initialize();
    _future.then((repo) {
      _repo = repo;
      // Apply the saved Light/Dark/System preference once settings are loaded.
      appThemeMode.value = repo.settings.themeMode;
      // Kick off the looping background music (no-op if disabled).
      repo.audio.startMusic();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Don't let the loop play over other apps or on the lock screen.
    if (state == AppLifecycleState.resumed) {
      _repo?.audio.resumeMusicIfEnabled();
    } else {
      _repo?.audio.pauseMusic();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppRepository>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(22)),
                    child: Image(
                        image: AssetImage('assets/icon/logo.png'),
                        width: 104,
                        height: 104),
                  ),
                  SizedBox(height: 16),
                  Text('Word Sprint',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800)),
                  SizedBox(height: 24),
                  CircularProgressIndicator(),
                ],
              ),
            ),
          );
        }
        if (snap.hasError) {
          return Scaffold(
            body: Center(child: Text('Failed to load: ${snap.error}')),
          );
        }
        return HomeScreen(repo: snap.data!);
      },
    );
  }
}

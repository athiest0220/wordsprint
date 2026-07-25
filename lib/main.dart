import 'package:flutter/material.dart';

import 'services/app_repository.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

void main() {
  runApp(const SpeedBeeApp());
}

class SpeedBeeApp extends StatelessWidget {
  const SpeedBeeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Word Sprint',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const _Bootstrap(),
    );
  }
}

/// Loads the dictionary + stores once, showing a splash until ready.
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  late final Future<AppRepository> _future;

  @override
  void initState() {
    super.initState();
    _future = AppRepository.initialize();
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

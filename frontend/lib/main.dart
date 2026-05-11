import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app.dart';

/// Captured before GoRouter initialises so the splash screen can restore
/// the intended URL even when auth redirects would otherwise overwrite it.
String initialWebRoute = '/';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    final uri = Uri.base;
    initialWebRoute = uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
  }

  await dotenv.load(fileName: '.env');
  runApp(const ProviderScope(child: App()));
}

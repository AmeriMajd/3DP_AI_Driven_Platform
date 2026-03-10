import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'app.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy(); // ← supprime le # des URLs
  await dotenv.load(fileName: '.env');
  runApp(const ProviderScope(child: App()));
}

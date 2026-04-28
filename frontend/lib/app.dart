import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/router/app_router.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context){
    return MaterialApp.router(
      title: '3DP Intelligence',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      routerConfig: appRouter,
      // Enables mouse-drag scrolling on Flutter web.
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.stylus,
        },
      ),
    );
  }
}
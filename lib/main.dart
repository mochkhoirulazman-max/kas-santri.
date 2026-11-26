import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'providers/kas_santri_provider.dart';
import 'providers/theme_wallpaper_provider.dart';
import 'screens/splash_screen.dart';
import 'utils/theme.dart';
import 'widgets/app_background_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => KasSantriProvider()),
        ChangeNotifierProvider(create: (_) => ThemeWallpaperProvider()..init()),
      ],
      child: const KasSantriApp(),
    ),
  );
}

class KasSantriApp extends StatelessWidget {
  const KasSantriApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kas-Santri — Manajemen Uang Saku & Infak Pondok',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      builder: (context, child) {
        return AppBackgroundWrapper(
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const SplashScreen(),
    );
  }
}

// lib/main.dart

import 'package:flutter/material.dart';
import 'package:kupon_bbm_app/core/di/dependency_injection.dart';
import 'package:kupon_bbm_app/core/themes/app_theme.dart';
import 'package:kupon_bbm_app/domain/repositories/kupon_repository.dart';
import 'package:kupon_bbm_app/domain/repositories/master_data_repository.dart';
import 'package:kupon_bbm_app/presentation/pages/main_page.dart';
import 'package:kupon_bbm_app/presentation/providers/dashboard_provider.dart';
import 'package:kupon_bbm_app/presentation/providers/enhanced_import_provider.dart';
import 'package:kupon_bbm_app/presentation/providers/kupon_provider.dart';
import 'package:kupon_bbm_app/presentation/providers/master_data_provider.dart';
import 'package:provider/provider.dart';
import 'package:kupon_bbm_app/presentation/providers/transaksi_provider.dart';
import 'package:kupon_bbm_app/domain/repositories/transaksi_repository_impl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // Initialize dependencies and localization
  await Future.wait([
    initializeDependencies(),
    initializeDateFormatting('id_ID'),
  ]);

  // Run app with providers
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => DashboardProvider(getIt<KuponRepository>()),
        ),
        ChangeNotifierProvider(
          create: (_) => TransaksiProvider(getIt<TransaksiRepositoryImpl>()),
        ),
        ChangeNotifierProvider(
          create: (_) => KuponProvider(getIt<KuponRepository>()),
        ),
        ChangeNotifierProvider(
          create: (_) => MasterDataProvider(getIt<MasterDataRepository>()),
        ),
        ChangeNotifierProvider(create: (_) => getIt<EnhancedImportProvider>()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kupon BBM Desktop App',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('id', 'ID'), // Indonesian
      ],
      locale: const Locale('id', 'ID'),
      home: const MainPage(),
    );
  }
}

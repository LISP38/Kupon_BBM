// lib/main.dart

import 'package:flutter/material.dart';
import 'package:kupon_bbm_app/core/di/dependency_injection.dart';
import 'package:kupon_bbm_app/core/themes/app_theme.dart';
import 'package:kupon_bbm_app/data/datasources/excel_datasource.dart';
import 'package:kupon_bbm_app/domain/repositories/kendaraan_repository.dart';
import 'package:kupon_bbm_app/domain/repositories/kupon_repository.dart';
import 'package:kupon_bbm_app/presentation/pages/main_page.dart';
import 'package:kupon_bbm_app/presentation/providers/dashboard_provider.dart';
import 'package:kupon_bbm_app/presentation/providers/import_provider.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // Initialize dependencies
  await initializeDependencies();

  // Run app with providers
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ImportProvider(
            getIt<ExcelDatasource>(),
            getIt<KuponRepository>(),
            getIt<KendaraanRepository>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => DashboardProvider(getIt<KuponRepository>()),
        ),
        // Daftarkan provider lain di sini nanti
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
      home: const MainPage(),
    );
  }
}

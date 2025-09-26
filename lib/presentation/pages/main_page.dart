import 'package:flutter/material.dart';
import 'package:kupon_bbm_app/presentation/pages/dashboard/dashboard_page.dart';
import 'package:kupon_bbm_app/presentation/pages/import/import_page.dart';
import 'package:kupon_bbm_app/presentation/pages/transaction/transaction_page.dart';
import 'package:provider/provider.dart';
import 'package:kupon_bbm_app/presentation/providers/dashboard_provider.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}


class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  // Keep a key for the dashboard to access its context/provider
  final GlobalKey _dashboardKey = GlobalKey();

  Widget _buildPage(int index) {
    if (index == 0) {
      // ImportPage with callback to refresh dashboard
      return ImportPage(
        onImportSuccess: () {
          // Find DashboardProvider and refresh
          if (_dashboardKey.currentContext != null) {
            final provider = Provider.of<DashboardProvider>(
              _dashboardKey.currentContext!,
              listen: false,
            );
            provider.fetchKupons();
          }
        },
      );
    } else if (index == 1) {
      // DashboardPage with key
      return DashboardPage(key: _dashboardKey);
    } else {
      return const TransactionPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: const <NavigationRailDestination>[
              NavigationRailDestination(
                icon: Icon(Icons.upload_file),
                selectedIcon: Icon(Icons.upload_file_outlined),
                label: Text('Import Excel'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.dashboard),
                selectedIcon: Icon(Icons.dashboard_outlined),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.receipt_long),
                selectedIcon: Icon(Icons.receipt_long_outlined),
                label: Text('Data Transaksi'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          // Halaman konten akan ditampilkan di sini
          Expanded(
            child: _buildPage(_selectedIndex),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:kupon_bbm_app/presentation/pages/dashboard/dashboard_page.dart';
import 'package:kupon_bbm_app/presentation/pages/import/import_page.dart';
import 'package:kupon_bbm_app/presentation/pages/transaction/transaction_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  // Daftar halaman sesuai urutan menu
  final List<Widget> _pages = [
    const ImportPage(),
    const DashboardPage(),
    const TransactionPage(),
  ];

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
            child: _pages[_selectedIndex],
          ),
        ],
      ),
    );
  }
}
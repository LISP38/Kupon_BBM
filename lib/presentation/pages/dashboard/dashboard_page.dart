import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dropdown_search/dropdown_search.dart';

import '../../../core/di/dependency_injection.dart';
import '../../../domain/entities/kendaraan_entity.dart';
import '../../../domain/entities/kupon_entity.dart';
import '../../../data/models/kendaraan_model.dart';
import '../../../domain/repositories/kendaraan_repository.dart';
import '../../../data/services/export_service.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/master_data_provider.dart';
import '../../providers/transaksi_provider.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with TickerProviderStateMixin {
  // Constants for BBM types
  final Map<int, String> _jenisBBMMap = {1: 'Pertamax', 2: 'Pertamina Dex'};

  // Lists for dropdown data
  final List<int> _bulanList = List.generate(12, (i) => i + 1);
  final List<int> _tahunList = [2024, 2025]; // TODO: Dynamic tahun
  List<KendaraanEntity> _kendaraanList = [];

  // Tab controller
  late TabController _tabController;

  // Filter controllers
  final TextEditingController _nomorKuponController = TextEditingController();
  final TextEditingController _nopolController = TextEditingController();
  String? _selectedSatker;
  String? _selectedJenisBBM;
  String? _selectedJenisRanmor;
  int? _selectedBulan;
  int? _selectedTahun;

  bool _firstLoad = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _fetchKendaraanList();
    _fetchSatkerList();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;

    // Terapkan filter default untuk tab yang aktif
    final defaultJenisKupon = _tabController.index == 0 ? '1' : '2';
    final provider = Provider.of<DashboardProvider>(context, listen: false);

    // Set filter dengan mempertahankan filter yang sudah ada
    provider.setFilter(
      jenisKupon: defaultJenisKupon,
      jenisBBM: _selectedJenisBBM,
      satker: _selectedSatker,
      nopol: _nopolController.text.isNotEmpty ? _nopolController.text : null,
      jenisRanmor: _selectedJenisRanmor,
      bulanTerbit: _selectedBulan,
      tahunTerbit: _selectedTahun,
      nomorKupon: _nomorKuponController.text.isNotEmpty
          ? _nomorKuponController.text
          : null,
    );

    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            SizedBox(width: 16),
            Text('Memuat data...'),
          ],
        ),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nomorKuponController.dispose();
    _nopolController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_firstLoad) {
      _firstLoad = false;

      // Schedule the initial data fetch for the next frame
      Future.microtask(() {
        if (!mounted) return;

        final provider = Provider.of<DashboardProvider>(context, listen: false);
        final masterDataProvider = Provider.of<MasterDataProvider>(
          context,
          listen: false,
        );

        // Set initial filters
        provider.nomorKupon = null;
        provider.satker = null;
        provider.jenisBBM = null;
        provider.jenisKupon = '1';
        provider.nopol = null;
        provider.jenisRanmor = null;
        provider.bulanTerbit = null;
        provider.tahunTerbit = null;

        // Fetch initial data
        provider.fetchRanjenKupons();
        provider.fetchSatkers();
        masterDataProvider.fetchSatkers();
      });
    }
  }

  Future<void> _fetchKendaraanList() async {
    final repo = getIt<KendaraanRepository>();
    _kendaraanList = await repo.getAllKendaraan();
    setState(() {});
  }

  Future<void> _fetchSatkerList() async {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    await provider.fetchSatkers();
  }

  bool _isFilterVisible = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Kupon'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Import Data',
            onPressed: () async { /* ... */ },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.directions_car), text: 'Data Ranjen'),
            Tab(icon: Icon(Icons.support), text: 'Data Dukungan'),
          ],
        ),
      ),
      // TAMBAHKAN FLOATING ACTION BUTTON UNTUK TOGGLE FILTER
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _isFilterVisible = !_isFilterVisible;
          });
        },
        backgroundColor: Colors.blue,
        child: Icon(_isFilterVisible ? Icons.filter_alt_off : Icons.filter_alt),
        tooltip: _isFilterVisible ? 'Sembunyikan Filter' : 'Tampilkan Filter',
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRanjenContent(context),
          _buildDukunganContent(context),
        ],
      ),
    );
  }

  Widget _buildRanjenContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummarySection(context),
          // GUNAKAN IF UNTUK MENYEMBUNYIKAN/MENAMPILKAN FILTER
          if (_isFilterVisible) _buildRanjenFilterSection(context),
          const SizedBox(height: 16),
          Expanded(child: _buildRanjenTable(context)),
          // TAMBAHKAN KONTROL PAGINATION
          _buildPaginationControls(
            currentPage: Provider.of<DashboardProvider>(context).ranjenCurrentPage,
            totalPages: Provider.of<DashboardProvider>(context).ranjenTotalPages,
            onPrevious: () => Provider.of<DashboardProvider>(context, listen: false).previousRanjenPage(),
            onNext: () => Provider.of<DashboardProvider>(context, listen: false).nextRanjenPage(),
          ),
          const SizedBox(height: 16), // Beri jarak dengan tombol export
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () => _showExportDialog(context),
              icon: const Icon(Icons.download),
              label: const Text('Export Data'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDukunganContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummarySection(context),
          // GUNAKAN IF UNTUK MENYEMBUNYIKAN/MENAMPILKAN FILTER
          if (_isFilterVisible) _buildDukunganFilterSection(context),
          const SizedBox(height: 16),
          Expanded(child: _buildDukunganTable(context)),
          // TAMBAHKAN KONTROL PAGINATION
          _buildPaginationControls(
            currentPage: Provider.of<DashboardProvider>(context).dukunganCurrentPage,
            totalPages: Provider.of<DashboardProvider>(context).dukunganTotalPages,
            onPrevious: () => Provider.of<DashboardProvider>(context, listen: false).previousDukunganPage(),
            onNext: () => Provider.of<DashboardProvider>(context, listen: false).nextDukunganPage(),
          ),
          const SizedBox(height: 16), // Beri jarak dengan tombol export
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () => _showExportDialog(context),
              icon: const Icon(Icons.download),
              label: const Text('Export Data'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, provider, _) {
        // Gunakan data yang tepat berdasarkan tab yang aktif
        final activeTabKuponCount = _tabController.index == 0
            ? provider.ranjenKupons.length
            : provider.dukunganKupons.length;

        return Card(
          color: Colors.blue.shade50,
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Text(
                  'Total Kupon (${_tabController.index == 0 ? 'Ranjen' : 'Dukungan'}): ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  activeTabKuponCount.toString(),
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.blue.shade900,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getNopolByKendaraanId(int? kendaraanId) {
    // Handle DUKUNGAN coupons that don't have kendaraan
    if (kendaraanId == null) return 'N/A (DUKUNGAN)';

    final kendaraan = _kendaraanList.firstWhere(
      (k) => k.kendaraanId == kendaraanId,
      orElse: () => KendaraanModel(
        kendaraanId: 0,
        satkerId: 0,
        jenisRanmor: '-',
        noPolKode: '-',
        noPolNomor: '-',
      ),
    );
    if (kendaraan.kendaraanId == 0) return '-';
    return '${kendaraan.noPolNomor}-${kendaraan.noPolKode}';
  }

  void _resetFilters() {
    setState(() {
      _nomorKuponController.clear();
      _nopolController.clear();
      _selectedSatker = null;
      _selectedJenisBBM = null;
      _selectedJenisRanmor = null;
      _selectedBulan = null;
      _selectedTahun = null;
    });

    // Apply default filters based on the active tab
    final provider = Provider.of<DashboardProvider>(context, listen: false);

    // Reset provider filters
    provider.resetFilters();

    // Set jenis kupon based on current tab after reset
    final defaultJenisKupon = _tabController.index == 0 ? '1' : '2';
    provider.setFilter(
      jenisKupon: defaultJenisKupon,
      nomorKupon: null,
      satker: null,
      jenisBBM: null,
      nopol: null,
      jenisRanmor: null,
      bulanTerbit: null,
      tahunTerbit: null,
    );
  }

  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.file_download, color: Colors.blue),
              const SizedBox(width: 8),
              const Text('Export Data'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pilih jenis data yang ingin di-export:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.maxFinite,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await _exportDataKupon();
                  },
                  icon: const Icon(Icons.description),
                  label: const Text('Data Kupon (4 Sheet)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 16, top: 4),
                child: Text(
                  'RAN.PX, DUK.PX, RAN.DX, DUK.DX',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.maxFinite,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await _exportDataSatker();
                  },
                  icon: const Icon(Icons.business),
                  label: const Text('Data Satker (2 Sheet)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 16, top: 4),
                child: Text(
                  'REKAP.PX, REKAP.DX',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.amber.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Data akan di-export dalam format Excel (.xlsx)',
                        style: TextStyle(
                          color: Colors.amber.shade800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Batal'),
            ),
          ],
        );
      },
    );
  }

  // Ganti fungsi _exportDataKupon yang ada dengan ini
  Future<void> _exportDataKupon() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Menyiapkan Data Kupon (4 Sheet)...'),
            ],
          ),
        ),
      );

      final provider = Provider.of<DashboardProvider>(context, listen: false);

      // --- PERBAIKAN: Pastikan data dari kedua tab sudah dimuat ---
      print('[EXPORT] Memastikan data Ranjen dan Dukungan sudah dimuat...');

      // Jika data Ranjen kosong, ambil dulu
      if (provider.ranjenKupons.isEmpty) {
        print('[EXPORT] Data Ranjen kosong, mengambil data...');
        await provider.fetchRanjenKupons();
      } else {
        print('[EXPORT] Data Ranjen sudah ada.');
      }

      // Jika data Dukungan kosong, ambil dulu
      if (provider.dukunganKupons.isEmpty) {
        print('[EXPORT] Data Dukungan kosong, mengambil data...');
        await provider.fetchDukunganKupons();
      } else {
        print('[EXPORT] Data Dukungan sudah ada.');
      }

      print(
        '[EXPORT] Total data yang akan diekspor: ${provider.allKuponsForExport.length}',
      );

      // Sekarang, periksa lagi apakah data gabungan benar-benar kosong
      if (provider.allKuponsForExport.isEmpty) {
        Navigator.of(context).pop(); // Tutup dialog loading
        _showMessage('Tidak ada data kupon untuk di-export', isError: true);
        return;
      }

      final success = await ExportService.exportDataKupon(
        allKupons: provider.allKuponsForExport,
        jenisBBMMap: _jenisBBMMap,
        getNopolByKendaraanId: _getNopolByKendaraanId,
        getJenisRanmorByKendaraanId: _getJenisRanmorByKendaraanId,
      );

      Navigator.of(context).pop(); // Tutup dialog loading

      if (success) {
        _showMessage(
          'Data Kupon berhasil di-export! (RAN.PX, DUK.PX, RAN.DX, DUK.DX)',
        );
      } else {
        _showMessage('Export dibatalkan atau gagal', isError: true);
      }
    } catch (e) {
      Navigator.of(context).pop(); // Tutup dialog loading jika terjadi error
      _showMessage('Error saat export data: $e', isError: true);
    }
  }

  // Ganti fungsi _exportDataSatker yang ada dengan ini
  Future<void> _exportDataSatker() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Menyiapkan Data Satker (2 Sheet)...'),
            ],
          ),
        ),
      );

      final provider = Provider.of<DashboardProvider>(context, listen: false);

      // --- PERBAIKAN: Pastikan data dari kedua tab sudah dimuat ---
      print(
        '[EXPORT SATKER] Memastikan data Ranjen dan Dukungan sudah dimuat...',
      );

      if (provider.ranjenKupons.isEmpty) {
        print('[EXPORT SATKER] Data Ranjen kosong, mengambil data...');
        await provider.fetchRanjenKupons();
      }

      if (provider.dukunganKupons.isEmpty) {
        print('[EXPORT SATKER] Data Dukungan kosong, mengambil data...');
        await provider.fetchDukunganKupons();
      }

      print(
        '[EXPORT SATKER] Total data yang akan diekspor: ${provider.allKuponsForExport.length}',
      );

      if (provider.allKuponsForExport.isEmpty) {
        Navigator.of(context).pop(); // Tutup dialog loading
        _showMessage('Tidak ada data kupon untuk di-export', isError: true);
        return;
      }

      final success = await ExportService.exportDataSatker(
        allKupons: provider.allKuponsForExport,
        jenisBBMMap: _jenisBBMMap,
      );

      Navigator.of(context).pop(); // Tutup dialog loading

      if (success) {
        _showMessage('Data Satker berhasil di-export! (REKAP.PX, REKAP.DX)');
      } else {
        _showMessage('Export dibatalkan atau gagal', isError: true);
      }
    } catch (e) {
      Navigator.of(context).pop(); // Tutup dialog loading jika terjadi error
      _showMessage('Error saat export data: $e', isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error : Icons.check_circle,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Kupon'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Import Data',
            onPressed: () async {
              await Navigator.pushNamed(context, '/import');
              // PERBAIKAN: Gunakan refreshData() untuk mempertahankan filter/tab saat ini
              if (mounted) {
                final provider = Provider.of<DashboardProvider>(
                  context,
                  listen: false,
                );
                await provider.fetchSatkers(); // Tetap refresh satker
                await provider
                    .refreshData(); // Gunakan metode refresh yang sudah disediakan
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.directions_car), text: 'Data Ranjen'),
            Tab(icon: Icon(Icons.support), text: 'Data Dukungan'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRanjenContent(context),
          _buildDukunganContent(context),
        ],
      ),
    );
  }

  Widget _buildRanjenFilterSection(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nomorKuponController,
                    decoration: const InputDecoration(
                      labelText: 'Nomor Kupon',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _nopolController,
                    decoration: const InputDecoration(
                      labelText: 'NoPol',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedSatker,
                    decoration: const InputDecoration(
                      labelText: 'Satker',
                      border: OutlineInputBorder(),
                    ),
                    items: provider.satkerList
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedSatker = value),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedJenisBBM,
                    decoration: const InputDecoration(
                      labelText: 'Jenis BBM',
                      border: OutlineInputBorder(),
                    ),
                    items: _jenisBBMMap.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key.toString(),
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedJenisBBM = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownSearch<String>(
                    popupProps: const PopupProps.menu(
                      showSearchBox: true,
                      searchFieldProps: TextFieldProps(
                        decoration: InputDecoration(
                          hintText: 'Cari jenis ranmor...',
                        ),
                      ),
                    ),
                    items: _kendaraanList
                        .map((k) => k.jenisRanmor)
                        .toSet()
                        .toList(),
                    dropdownDecoratorProps: const DropDownDecoratorProps(
                      dropdownSearchDecoration: InputDecoration(
                        labelText: 'Jenis Ranmor',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    onChanged: (value) =>
                        setState(() => _selectedJenisRanmor = value),
                    selectedItem: _selectedJenisRanmor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedBulan,
                    decoration: const InputDecoration(
                      labelText: 'Bulan',
                      border: OutlineInputBorder(),
                    ),
                    items: _bulanList
                        .map(
                          (b) => DropdownMenuItem(
                            value: b,
                            child: Text(b.toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedBulan = value),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedTahun,
                    decoration: const InputDecoration(
                      labelText: 'Tahun',
                      border: OutlineInputBorder(),
                    ),
                    items: _tahunList
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(t.toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedTahun = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    final provider = Provider.of<DashboardProvider>(
                      context,
                      listen: false,
                    );
                    provider.setFilter(
                      nomorKupon: _nomorKuponController.text.isNotEmpty
                          ? _nomorKuponController.text
                          : null,
                      satker: _selectedSatker,
                      jenisBBM: _selectedJenisBBM,
                      jenisKupon: '1', // Ranjen
                      nopol: _nopolController.text.isNotEmpty
                          ? _nopolController.text
                          : null,
                      jenisRanmor: _selectedJenisRanmor,
                      bulanTerbit: _selectedBulan,
                      tahunTerbit: _selectedTahun,
                    );

                    // Show loading indicator
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Row(
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                            SizedBox(width: 16),
                            Text('Memuat data...'),
                          ],
                        ),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  icon: const Icon(Icons.filter_alt),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  label: const Text('Filter'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    _resetFilters();
                    // Show loading indicator
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Row(
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                            SizedBox(width: 16),
                            Text('Mereset filter...'),
                          ],
                        ),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  icon: const Icon(Icons.refresh),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                  ),
                  label: const Text('Reset Filter'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDukunganFilterSection(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nomorKuponController,
                    decoration: const InputDecoration(
                      labelText: 'Nomor Kupon',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _nopolController,
                    decoration: const InputDecoration(
                      labelText: 'NoPol',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedSatker,
                    decoration: const InputDecoration(
                      labelText: 'Satker',
                      border: OutlineInputBorder(),
                    ),
                    items: provider.satkerList
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedSatker = value),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedJenisBBM,
                    decoration: const InputDecoration(
                      labelText: 'Jenis BBM',
                      border: OutlineInputBorder(),
                    ),
                    items: _jenisBBMMap.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key.toString(),
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedJenisBBM = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownSearch<String>(
                    popupProps: const PopupProps.menu(
                      showSearchBox: true,
                      searchFieldProps: TextFieldProps(
                        decoration: InputDecoration(
                          hintText: 'Cari jenis ranmor...',
                        ),
                      ),
                    ),
                    items: _kendaraanList
                        .map((k) => k.jenisRanmor)
                        .toSet()
                        .toList(),
                    dropdownDecoratorProps: const DropDownDecoratorProps(
                      dropdownSearchDecoration: InputDecoration(
                        labelText: 'Jenis Ranmor',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    onChanged: (value) =>
                        setState(() => _selectedJenisRanmor = value),
                    selectedItem: _selectedJenisRanmor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedBulan,
                    decoration: const InputDecoration(
                      labelText: 'Bulan',
                      border: OutlineInputBorder(),
                    ),
                    items: _bulanList
                        .map(
                          (b) => DropdownMenuItem(
                            value: b,
                            child: Text(b.toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedBulan = value),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedTahun,
                    decoration: const InputDecoration(
                      labelText: 'Tahun',
                      border: OutlineInputBorder(),
                    ),
                    items: _tahunList
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(t.toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedTahun = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    provider.setFilter(
                      nomorKupon: _nomorKuponController.text.isNotEmpty
                          ? _nomorKuponController.text
                          : null,
                      satker: _selectedSatker,
                      jenisBBM: _selectedJenisBBM,
                      jenisKupon: '2', // Dukungan
                      nopol: _nopolController.text.isNotEmpty
                          ? _nopolController.text
                          : null,
                      jenisRanmor: _selectedJenisRanmor,
                      bulanTerbit: _selectedBulan,
                      tahunTerbit: _selectedTahun,
                    );
                  },
                  icon: const Icon(Icons.search),
                  label: const Text('Filter'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _resetFilters,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset Filter'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Ganti fungsi _buildRanjenTable yang ada dengan ini
  Widget _buildRanjenTable(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, provider, _) {
        final kupons = provider.ranjenKupons;
        if (kupons.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text(
                'Data Ranjen tidak ditemukan',
                style: TextStyle(fontSize: 18),
              ),
            ),
          );
        }

        // PERBAIKAN: Sederhanakan struktur scrolling
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('No')),
              DataColumn(label: Text('No Kupon')),
              DataColumn(label: Text('Satker')),
              DataColumn(label: Text('Jenis BBM')),
              DataColumn(label: Text('NoPol')),
              DataColumn(label: Text('Jenis Ranmor')),
              DataColumn(label: Text('Bulan/Tahun')),
              DataColumn(label: Text('Kuota Sisa')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Aksi')),
            ],
            rows: kupons.asMap().entries.map((entry) {
              final i = entry.key + 1;
              final k = entry.value;
              return DataRow(
                cells: [
                  DataCell(Text(i.toString())),
                  DataCell(
                    Text(
                      '${k.nomorKupon}/${k.bulanTerbit}/${k.tahunTerbit}/LOGISTIK',
                    ),
                  ),
                  DataCell(Text(k.namaSatker)),
                  DataCell(
                    Text(_jenisBBMMap[k.jenisBbmId] ?? k.jenisBbmId.toString()),
                  ),
                  DataCell(Text(_getNopolByKendaraanId(k.kendaraanId))),
                  DataCell(Text(_getJenisRanmorByKendaraanId(k.kendaraanId))),
                  DataCell(Text('${k.bulanTerbit}/${k.tahunTerbit}')),
                  DataCell(Text('${k.kuotaSisa.toStringAsFixed(2)} L')),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: k.status == 'Aktif' ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        k.status,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  DataCell(
                    IconButton(
                      icon: const Icon(Icons.info_outline, color: Colors.blue),
                      tooltip: 'Lihat Detail Kupon',
                      onPressed: () => _showKuponDetailDialog(context, k),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // Ganti fungsi _buildDukunganTable yang ada dengan ini
  Widget _buildDukunganTable(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, provider, _) {
        final kupons = provider.dukunganKupons;
        if (kupons.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text(
                'Data Dukungan tidak ditemukan',
                style: TextStyle(fontSize: 18),
              ),
            ),
          );
        }

        // PERBAIKAN: Sederhanakan struktur scrolling dan tetap gunakan Card
        return Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('No.')),
                DataColumn(label: Text('Nomor Kupon')),
                DataColumn(label: Text('Satker')),
                DataColumn(label: Text('Jenis BBM')),
                DataColumn(label: Text('Bulan/Tahun')),
                DataColumn(label: Text('Kuota Sisa')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Aksi')),
              ],
              rows: kupons.asMap().entries.map((entry) {
                final i = entry.key + 1;
                final k = entry.value;
                return DataRow(
                  cells: [
                    DataCell(Text(i.toString())),
                    DataCell(
                      Text(
                        '${k.nomorKupon}/${k.bulanTerbit}/${k.tahunTerbit}/LOGISTIK',
                      ),
                    ),
                    DataCell(Text(k.namaSatker)),
                    DataCell(
                      Text(
                        _jenisBBMMap[k.jenisBbmId] ?? k.jenisBbmId.toString(),
                      ),
                    ),
                    DataCell(Text('${k.bulanTerbit}/${k.tahunTerbit}')),
                    DataCell(Text('${k.kuotaSisa.toStringAsFixed(2)} L')),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: k.status == 'Aktif'
                              ? Colors.green
                              : Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          k.status,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    DataCell(
                      IconButton(
                        icon: const Icon(
                          Icons.info_outline,
                          color: Colors.blue,
                        ),
                        tooltip: 'Lihat Detail Kupon',
                        onPressed: () => _showKuponDetailDialog(context, k),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  String _getJenisRanmorByKendaraanId(int? kendaraanId) {
    if (kendaraanId == null) return 'N/A';

    final kendaraan = _kendaraanList.firstWhere(
      (k) => k.kendaraanId == kendaraanId,
      orElse: () => KendaraanModel(
        kendaraanId: 0,
        satkerId: 0,
        jenisRanmor: '-',
        noPolKode: '-',
        noPolNomor: '-',
      ),
    );
    if (kendaraan.kendaraanId == 0) return '-';
    return kendaraan.jenisRanmor;
  }

  Future<void> _showKuponDetailDialog(
    BuildContext context,
    KuponEntity kupon,
  ) async {
    final tanggalTerbit = DateTime(kupon.tahunTerbit, kupon.bulanTerbit, 1);
    final tanggalKadaluarsa = tanggalTerbit.add(const Duration(days: 60));

    final transaksiProvider = Provider.of<TransaksiProvider>(
      context,
      listen: false,
    );
    await transaksiProvider.fetchTransaksiFiltered();
    final transaksiList = transaksiProvider.transaksiList
        .where((t) => t.kuponId == kupon.kuponId)
        .toList();

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 16, 0),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Detail Kupon'),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                _buildDetailRow(
                  'Nomor Kupon',
                  '${kupon.nomorKupon}/${kupon.bulanTerbit}/${kupon.tahunTerbit}/LOGISTIK',
                ),
                _buildDetailRow(
                  'Jenis BBM',
                  _jenisBBMMap[kupon.jenisBbmId] ?? kupon.jenisBbmId.toString(),
                ),
                _buildDetailRow(
                  'Jenis Kupon',
                  kupon.jenisKuponId == 1 ? 'RANJEN' : 'DUKUNGAN',
                ),
                _buildDetailRow(
                  'Kuota Awal',
                  '${kupon.kuotaAwal.toStringAsFixed(2)} L',
                ),
                _buildDetailRow(
                  'Kuota Sisa',
                  '${kupon.kuotaSisa.toStringAsFixed(2)} L',
                ),
                _buildDetailRow('Status', kupon.status),
                _buildDetailRow(
                  'Tanggal Terbit',
                  '${tanggalTerbit.day}/${tanggalTerbit.month}/${tanggalTerbit.year}',
                ),
                _buildDetailRow(
                  'Tanggal Kadaluarsa',
                  '${tanggalKadaluarsa.day}/${tanggalKadaluarsa.month}/${tanggalKadaluarsa.year}',
                ),
                const Divider(height: 32),
                const Text(
                  'Riwayat Penggunaan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (transaksiList.isNotEmpty) ...[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Tanggal')),
                        DataColumn(label: Text('Jumlah (L)')),
                      ],
                      rows: transaksiList
                          .map(
                            (t) => DataRow(
                              cells: [
                                DataCell(Text(t.tanggalTransaksi)),
                                DataCell(Text('${t.jumlahLiter} L')),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ] else
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Belum ada penggunaan kupon',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const Text(': '),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

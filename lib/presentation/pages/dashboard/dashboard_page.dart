import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dropdown_search/dropdown_search.dart';

import '../../../core/di/dependency_injection.dart';
import '../../../domain/entities/kendaraan_entity.dart';
import '../../../data/models/kendaraan_model.dart';
import '../../../domain/repositories/kendaraan_repository.dart';
import '../../../data/services/export_service.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/master_data_provider.dart';

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

    // Reset filters when changing tabs
    _resetFilters();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_firstLoad) {
      _firstLoad = false;
      final provider = Provider.of<DashboardProvider>(context, listen: false);
      final masterDataProvider = Provider.of<MasterDataProvider>(
        context,
        listen: false,
      );

      // Fetch initial data
      provider.fetchKupons();
      provider.fetchSatkers();
      masterDataProvider.fetchSatkers();
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

  Widget _buildRanjenContent(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    // Always filter for Ranjen (jenis_kupon_id = 1)
    provider.setFilter(
      jenisKupon: '1',
      nomorKupon: _nomorKuponController.text,
      satker: _selectedSatker,
      jenisBBM: _selectedJenisBBM,
      nopol: _nopolController.text,
      jenisRanmor: _selectedJenisRanmor,
      bulanTerbit: _selectedBulan,
      tahunTerbit: _selectedTahun,
    );
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummarySection(context),
          _buildRanjenFilterSection(context),
          const SizedBox(height: 16),
          Expanded(child: _buildRanjenTable(context)),
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
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    // Always filter for Dukungan (jenis_kupon_id = 2)
    provider.setFilter(
      jenisKupon: '2',
      nomorKupon: _nomorKuponController.text,
      satker: _selectedSatker,
      jenisBBM: _selectedJenisBBM,
      nopol: _nopolController.text,
      jenisRanmor: _selectedJenisRanmor,
      bulanTerbit: _selectedBulan,
      tahunTerbit: _selectedTahun,
    );
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummarySection(context),
          _buildDukunganFilterSection(context),
          const SizedBox(height: 16),
          Expanded(child: _buildDukunganTable(context)),
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
        return Card(
          color: Colors.blue.shade50,
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Text(
                  'Total Kupon: ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  provider.kupons.length.toString(),
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

    // Apply empty filters to reset the view
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    provider.setFilter(
      nomorKupon: '',
      satker: null,
      jenisBBM: null,
      jenisKupon: null,
      nopol: '',
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

  Future<void> _exportDataKupon() async {
    try {
      // Show loading dialog
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

      if (provider.kupons.isEmpty) {
        Navigator.of(context).pop();
        _showMessage('Tidak ada data kupon untuk di-export', isError: true);
        return;
      }

      final success = await ExportService.exportDataKupon(
        allKupons: provider.kupons,
        jenisBBMMap: _jenisBBMMap,
        getNopolByKendaraanId: _getNopolByKendaraanId,
        getJenisRanmorByKendaraanId: _getJenisRanmorByKendaraanId,
      );

      Navigator.of(context).pop();

      if (success) {
        _showMessage(
          'Data Kupon berhasil di-export! (RAN.PX, DUK.PX, RAN.DX, DUK.DX)',
        );
      } else {
        _showMessage('Export dibatalkan atau gagal', isError: true);
      }
    } catch (e) {
      Navigator.of(context).pop();
      _showMessage('Error saat export data: $e', isError: true);
    }
  }

  Future<void> _exportDataSatker() async {
    try {
      // Show loading dialog
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

      if (provider.kupons.isEmpty) {
        Navigator.of(context).pop();
        _showMessage('Tidak ada data kupon untuk di-export', isError: true);
        return;
      }

      final success = await ExportService.exportDataSatker(
        allKupons: provider.kupons,
        jenisBBMMap: _jenisBBMMap,
      );

      Navigator.of(context).pop();

      if (success) {
        _showMessage('Data Satker berhasil di-export! (REKAP.PX, REKAP.DX)');
      } else {
        _showMessage('Export dibatalkan atau gagal', isError: true);
      }
    } catch (e) {
      Navigator.of(context).pop();
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
              // Setelah kembali dari import, refresh data
              if (mounted) {
                final provider = Provider.of<DashboardProvider>(
                  context,
                  listen: false,
                );
                await provider.fetchSatkers();
                await provider.fetchKupons();
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
                    initialValue: _selectedSatker,
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
                    initialValue: _selectedJenisBBM,
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
                    initialValue: _selectedBulan,
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
                    initialValue: _selectedTahun,
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
                      nomorKupon: _nomorKuponController.text,
                      satker: _selectedSatker,
                      jenisBBM: _selectedJenisBBM,
                      jenisKupon: '1', // Ranjen
                      nopol: _nopolController.text,
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

  Widget _buildDukunganFilterSection(BuildContext context) {
    return _buildRanjenFilterSection(context);
  }

  Widget _buildRanjenTable(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, provider, _) {
        final kupons = provider.kupons
            .where((k) => k.jenisKuponId == 1)
            .toList();
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
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
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
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDukunganTable(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, provider, _) {
        final kupons = provider.kupons
            .where((k) => k.jenisKuponId == 2)
            .toList();
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
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
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
                            _jenisBBMMap[k.jenisBbmId] ??
                                k.jenisBbmId.toString(),
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
                      ],
                    );
                  }).toList(),
                ),
              ),
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
}

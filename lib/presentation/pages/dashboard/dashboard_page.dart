import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'dart:io';

import '../../../core/di/dependency_injection.dart';
import '../../../domain/entities/kendaraan_entity.dart';
import '../../../domain/entities/kupon_entity.dart';
import '../../../data/models/kendaraan_model.dart';
import '../../../domain/repositories/kendaraan_repository.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/transaksi_provider.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // Constants for BBM and Kupon types
  final Map<int, String> _jenisBBMMap = {1: 'Pertamax', 2: 'Pertamina Dex'};
  final Map<int, String> _jenisKuponMap = {1: 'Ranjen', 2: 'Dukungan'};

  // Lists for dropdown data
  final List<int> _bulanList = List.generate(12, (i) => i + 1);
  final List<int> _tahunList = [2024, 2025]; // TODO: Dynamic tahun
  List<KendaraanEntity> _kendaraanList = [];

  // Filter controllers
  final TextEditingController _nomorKuponController = TextEditingController();
  final TextEditingController _nopolController = TextEditingController();
  String? _selectedSatker;
  String? _selectedJenisBBM;
  String? _selectedJenisKupon;
  String? _selectedJenisRanmor;
  int? _selectedBulan;
  int? _selectedTahun;

  // Pagination variables
  int _currentPage = 1;
  final int _itemsPerPage = 10;
  int _totalPages = 1;

  bool _firstLoad = true;

  @override
  void initState() {
    super.initState();
    _fetchKendaraanList();
    _fetchSatkerList();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Auto-refresh data setiap kali tab dashboard muncul
    if (_firstLoad) {
      Provider.of<DashboardProvider>(context, listen: false).fetchKupons();
      _firstLoad = false;
    }
  }

  Future<void> _fetchKendaraanList() async {
    final repo = getIt<KendaraanRepository>();
    _kendaraanList = await repo.getAllKendaraan();
    setState(() {});
  }

  Future<void> _fetchSatkerList() async {
    // final repo = getIt<MasterDataRepository>();
    // _satkerList = await repo.getAllSatker();
    // setState(() {});
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

  String _getNopolByKendaraanId(int kendaraanId) {
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
      _selectedJenisKupon = null;
      _selectedJenisRanmor = null;
      _selectedBulan = null;
      _selectedTahun = null;
      _currentPage = 1; // Reset pagination
    });

    // Apply empty filters to reset the view
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    provider.setFilter(
      nomorKupon: '',
      satker: null,
      jenisBBM: null,
      jenisKupon: null,
      nopol: '',
      bulanTerbit: null,
      tahunTerbit: null,
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
                Provider.of<DashboardProvider>(
                  context,
                  listen: false,
                ).fetchKupons();
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummarySection(context),
            _buildFilterSection(context),
            const SizedBox(height: 16),
            Expanded(child: _buildMasterKuponTable(context)),
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
      ),
    );
  }

  Widget _buildFilterSection(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.filter_list, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Filter Data Kupon',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _resetFilters,
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text('Reset Semua'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                // Nomor Kupon Filter
                SizedBox(
                  width: 200,
                  child: DropdownSearch<String>(
                    items: provider.kupons
                        .map((k) => k.nomorKupon)
                        .toSet()
                        .toList(),
                    selectedItem: _nomorKuponController.text.isEmpty
                        ? null
                        : _nomorKuponController.text,
                    dropdownDecoratorProps: const DropDownDecoratorProps(
                      dropdownSearchDecoration: InputDecoration(
                        labelText: 'Nomor Kupon',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.numbers),
                      ),
                    ),
                    popupProps: PopupProps.menu(
                      showSearchBox: true,
                      searchFieldProps: const TextFieldProps(
                        decoration: InputDecoration(
                          hintText: 'Cari Nomor Kupon...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      fit: FlexFit.loose,
                      constraints: const BoxConstraints(maxHeight: 300),
                    ),
                    onChanged: (val) =>
                        setState(() => _nomorKuponController.text = val ?? ''),
                    clearButtonProps: const ClearButtonProps(isVisible: true),
                  ),
                ),

                // Satker Filter
                SizedBox(
                  width: 200,
                  child: DropdownSearch<String>(
                    items: provider.kupons
                        .map((k) => k.namaSatker)
                        .toSet()
                        .toList(),
                    selectedItem: _selectedSatker,
                    dropdownDecoratorProps: const DropDownDecoratorProps(
                      dropdownSearchDecoration: InputDecoration(
                        labelText: 'Satker',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.business),
                      ),
                    ),
                    popupProps: PopupProps.menu(
                      showSearchBox: true,
                      searchFieldProps: const TextFieldProps(
                        decoration: InputDecoration(
                          hintText: 'Cari Satker...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      fit: FlexFit.loose,
                      constraints: const BoxConstraints(maxHeight: 300),
                    ),
                    onChanged: (val) => setState(() => _selectedSatker = val),
                    clearButtonProps: const ClearButtonProps(isVisible: true),
                  ),
                ),

                // Jenis BBM Filter
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    value: _selectedJenisBBM,
                    items: _jenisBBMMap.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.value,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => _selectedJenisBBM = val),
                    decoration: const InputDecoration(
                      labelText: 'Jenis BBM',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.local_gas_station),
                    ),
                  ),
                ),

                // Jenis Kupon Filter
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    value: _selectedJenisKupon,
                    items: _jenisKuponMap.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.value,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (val) =>
                        setState(() => _selectedJenisKupon = val),
                    decoration: const InputDecoration(
                      labelText: 'Jenis Kupon',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.confirmation_number),
                    ),
                  ),
                ),

                // NoPol Filter
                SizedBox(
                  width: 200,
                  child: DropdownSearch<String>(
                    items: _kendaraanList
                        .map((k) => '${k.noPolNomor}-${k.noPolKode}')
                        .toSet()
                        .toList(),
                    selectedItem: _nopolController.text.isEmpty
                        ? null
                        : _nopolController.text,
                    dropdownDecoratorProps: const DropDownDecoratorProps(
                      dropdownSearchDecoration: InputDecoration(
                        labelText: 'Nomor Polisi',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.directions_car),
                      ),
                    ),
                    popupProps: PopupProps.menu(
                      showSearchBox: true,
                      searchFieldProps: const TextFieldProps(
                        decoration: InputDecoration(
                          hintText: 'Cari Nomor Polisi...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      fit: FlexFit.loose,
                      constraints: const BoxConstraints(maxHeight: 300),
                    ),
                    onChanged: (val) =>
                        setState(() => _nopolController.text = val ?? ''),
                    clearButtonProps: const ClearButtonProps(isVisible: true),
                  ),
                ),

                // Jenis Ranmor Filter
                SizedBox(
                  width: 200,
                  child: DropdownSearch<String>(
                    items: _kendaraanList
                        .map((k) => k.jenisRanmor)
                        .toSet()
                        .toList(),
                    selectedItem: _selectedJenisRanmor,
                    dropdownDecoratorProps: const DropDownDecoratorProps(
                      dropdownSearchDecoration: InputDecoration(
                        labelText: 'Jenis Ranmor',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                      ),
                    ),
                    popupProps: PopupProps.menu(
                      showSearchBox: true,
                      searchFieldProps: const TextFieldProps(
                        decoration: InputDecoration(
                          hintText: 'Cari Jenis Ranmor...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      fit: FlexFit.loose,
                      constraints: const BoxConstraints(maxHeight: 300),
                    ),
                    onChanged: (val) =>
                        setState(() => _selectedJenisRanmor = val),
                    clearButtonProps: const ClearButtonProps(isVisible: true),
                  ),
                ),

                // Bulan Filter
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<int>(
                    value: _selectedBulan,
                    items: _bulanList
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(
                              e.toString().padLeft(2, '0'),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => _selectedBulan = val),
                    decoration: const InputDecoration(
                      labelText: 'Bulan',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                  ),
                ),

                // Tahun Filter
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<int>(
                    value: _selectedTahun,
                    items: _tahunList
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(
                              e.toString(),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => _selectedTahun = val),
                    decoration: const InputDecoration(
                      labelText: 'Tahun',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.date_range),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _currentPage = 1; // Reset to first page when filtering
                    });
                    provider.setFilter(
                      nomorKupon: _nomorKuponController.text,
                      satker: _selectedSatker,
                      jenisBBM: _selectedJenisBBM,
                      jenisKupon: _selectedJenisKupon,
                      nopol: _nopolController.text,
                      bulanTerbit: _selectedBulan,
                      tahunTerbit: _selectedTahun,
                    );
                  },
                  icon: const Icon(Icons.search),
                  label: const Text('Terapkan Filter'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _resetFilters,
                  icon: const Icon(Icons.clear),
                  label: const Text('Bersihkan Filter'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Total Data: ${provider.kupons.length}',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
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
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _showKuponDetailDialog(
    BuildContext context,
    KuponEntity k,
    KendaraanEntity kendaraan,
  ) async {
    final transaksiProvider = Provider.of<TransaksiProvider>(
      context,
      listen: false,
    );
    await transaksiProvider.fetchTransaksiFiltered();
    final transaksiList = transaksiProvider.transaksiList
        .where((t) => t.kuponId == k.kuponId)
        .toList();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 16, 0),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Detail Kupon'),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(ctx).pop(),
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
                const Text(
                  'Informasi Kupon',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  'Nomor Kupon',
                  '${k.nomorKupon}/${k.bulanTerbit}/${k.tahunTerbit}/${k.namaSatker}',
                ),
                _buildDetailRow(
                  'Jenis BBM',
                  _jenisBBMMap[k.jenisBbmId] ?? k.jenisBbmId.toString(),
                ),
                _buildDetailRow(
                  'Jenis Kupon',
                  _jenisKuponMap[k.jenisKuponId] ?? k.jenisKuponId.toString(),
                ),
                _buildDetailRow('Kuota Awal', '${k.kuotaAwal} liter'),
                _buildDetailRow('Kuota Sisa', '${k.kuotaSisa} liter'),
                _buildDetailRow('Status', k.status),
                const Divider(),
                const Text(
                  'Informasi Kendaraan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  'Nomor Polisi',
                  '${kendaraan.noPolNomor}-${kendaraan.noPolKode}',
                ),
                _buildDetailRow('Jenis Kendaraan', kendaraan.jenisRanmor),
                _buildDetailRow('Satker', k.namaSatker),
                const Divider(),
                if (transaksiList.isNotEmpty) ...[
                  const Text(
                    'Riwayat Transaksi',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
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
                                DataCell(Text('${t.jumlahLiter} liter')),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ] else
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Belum ada transaksi untuk kupon ini',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
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

  Widget _buildMasterKuponTable(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, provider, _) {
        final allKupons = provider.kupons;
        if (allKupons.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text(
                'Data tidak ditemukan',
                style: TextStyle(fontSize: 18),
              ),
            ),
          );
        }

        // Calculate pagination
        _totalPages = (allKupons.length / _itemsPerPage).ceil();
        final startIndex = (_currentPage - 1) * _itemsPerPage;
        final endIndex = (startIndex + _itemsPerPage).clamp(
          0,
          allKupons.length,
        );
        final paginatedKupons = allKupons.sublist(startIndex, endIndex);

        return Column(
          children: [
            // Table with scroll
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('No.')),
                          DataColumn(label: Text('Nomor Kupon')),
                          DataColumn(label: Text('Jenis BBM')),
                          DataColumn(label: Text('Jenis Kupon')),
                          DataColumn(label: Text('NoPol')),
                          DataColumn(label: Text('Kuota Awal')),
                          DataColumn(label: Text('Kuota Sisa')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Aksi')),
                        ],
                        rows: paginatedKupons.asMap().entries.map((entry) {
                          final i = startIndex + entry.key + 1;
                          final k = entry.value;
                          final kendaraan = _kendaraanList.firstWhere(
                            (kend) => kend.kendaraanId == k.kendaraanId,
                            orElse: () => KendaraanModel(
                              kendaraanId: 0,
                              satkerId: 0,
                              jenisRanmor: '-',
                              noPolKode: '-',
                              noPolNomor: '-',
                            ),
                          );
                          return DataRow(
                            cells: [
                              DataCell(Text(i.toString())),
                              DataCell(
                                Text(
                                  '${k.nomorKupon}/${k.bulanTerbit}/${k.tahunTerbit}/${k.namaSatker}',
                                ),
                              ),
                              DataCell(
                                Text(
                                  _jenisBBMMap[k.jenisBbmId] ??
                                      k.jenisBbmId.toString(),
                                ),
                              ),
                              DataCell(
                                Text(
                                  _jenisKuponMap[k.jenisKuponId] ??
                                      k.jenisKuponId.toString(),
                                ),
                              ),
                              DataCell(
                                Text(_getNopolByKendaraanId(k.kendaraanId)),
                              ),
                              DataCell(Text(k.kuotaAwal.toString())),
                              DataCell(Text(k.kuotaSisa.toString())),
                              DataCell(Text(k.status)),
                              DataCell(
                                IconButton(
                                  icon: const Icon(Icons.info_outline),
                                  onPressed: () => _showKuponDetailDialog(
                                    context,
                                    k,
                                    kendaraan,
                                  ),
                                  tooltip: 'Detail',
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Pagination Controls
            _buildPaginationControls(allKupons.length),
          ],
        );
      },
    );
  }

  Widget _buildPaginationControls(int totalItems) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: const BorderDirectional(top: BorderSide(color: Colors.grey)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Info text
          Text(
            'Halaman $_currentPage dari $_totalPages (Total: $totalItems item)',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          // Navigation buttons
          Row(
            children: [
              // First page
              IconButton(
                onPressed: _currentPage > 1 ? () => _goToPage(1) : null,
                icon: const Icon(Icons.first_page),
                tooltip: 'Halaman Pertama',
              ),
              // Previous page
              IconButton(
                onPressed: _currentPage > 1
                    ? () => _goToPage(_currentPage - 1)
                    : null,
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Halaman Sebelumnya',
              ),
              // Page numbers
              ..._buildPageNumbers(),
              // Next page
              IconButton(
                onPressed: _currentPage < _totalPages
                    ? () => _goToPage(_currentPage + 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Halaman Berikutnya',
              ),
              // Last page
              IconButton(
                onPressed: _currentPage < _totalPages
                    ? () => _goToPage(_totalPages)
                    : null,
                icon: const Icon(Icons.last_page),
                tooltip: 'Halaman Terakhir',
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPageNumbers() {
    List<Widget> pages = [];
    int startPage = (_currentPage - 2).clamp(1, _totalPages);
    int endPage = (_currentPage + 2).clamp(1, _totalPages);

    for (int i = startPage; i <= endPage; i++) {
      pages.add(
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          child: Material(
            color: i == _currentPage ? Colors.blue : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            child: InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () => _goToPage(i),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Text(
                  i.toString(),
                  style: TextStyle(
                    color: i == _currentPage ? Colors.white : Colors.black87,
                    fontWeight: i == _currentPage
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return pages;
  }

  void _goToPage(int page) {
    setState(() {
      _currentPage = page.clamp(1, _totalPages);
    });
  }

  Future<void> _showExportDialog(BuildContext context) async {
    bool exportKupon = true;
    bool exportSatker = false;
    int selectedMonth = DateTime.now().month;
    int selectedYear = DateTime.now().year;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Export Data'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pilih data yang akan diekspor:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: exportKupon,
                    onChanged: (value) {
                      setState(() => exportKupon = value ?? false);
                    },
                    title: const Text('Data Kupon'),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  CheckboxListTile(
                    value: exportSatker,
                    onChanged: (value) {
                      setState(() => exportSatker = value ?? false);
                    },
                    title: const Text('Data Satker'),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Pilih periode:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: selectedMonth,
                          items: List.generate(12, (i) => i + 1)
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(
                                    'Bulan ${e.toString().padLeft(2, '0')}',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(
                              () => selectedMonth = value ?? selectedMonth,
                            );
                          },
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: selectedYear,
                          items: [2024, 2025]
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(e.toString()),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(
                              () => selectedYear = value ?? selectedYear,
                            );
                          },
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: (!exportKupon && !exportSatker)
                      ? null
                      : () => Navigator.of(context).pop({
                          'exportKupon': exportKupon,
                          'exportSatker': exportSatker,
                          'month': selectedMonth,
                          'year': selectedYear,
                        }),
                  child: const Text('Export'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      await _exportToExcel(
        context,
        exportKupon: result['exportKupon'],
        exportSatker: result['exportSatker'],
        month: result['month'],
        year: result['year'],
      );
    }
  }

  Future<void> _exportToExcel(
    BuildContext context, {
    required bool exportKupon,
    required bool exportSatker,
    required int month,
    required int year,
  }) async {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final transaksiProvider = Provider.of<TransaksiProvider>(
      context,
      listen: false,
    );

    // Load transaksi data first
    await transaksiProvider.fetchTransaksi();
    print(
      '[EXPORT DEBUG] Total transaksi loaded: ${transaksiProvider.transaksiList.length}',
    );

    final kupons = provider.kupons;
    if (kupons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada data untuk diexport.')),
      );
      return;
    }

    final excel = Excel.createExcel();

    // Debug: Print data count
    print('[EXPORT DEBUG] Total kupons: ${kupons.length}');
    print(
      '[EXPORT DEBUG] Export kupon: $exportKupon, Export satker: $exportSatker',
    );

    // Create sheets based on export type
    late final Sheet sheetRanPx;
    late final Sheet sheetDukPx;
    late final Sheet sheetDexPx;
    late final Sheet sheetDukDex;
    late final Sheet sheetRekapPx;
    late final Sheet sheetRekapDx;

    // Handle kupon export
    if (exportKupon) {
      // Create 4 sheets for kupon data
      sheetRanPx = excel['RAN.PX'];
      sheetDukPx = excel['DUK.PX'];
      sheetDexPx = excel['RAN.DEX'];
      sheetDukDex = excel['DUK.DEX'];

      // Calculate days in month
      final daysInMonth = DateTime(year, month + 1, 0).day;

      // Header structure for all kupon sheets
      for (var sheet in [sheetRanPx, sheetDukPx, sheetDexPx, sheetDukDex]) {
        // ROW 0: Title row with period
        final periodTitle =
            'Periode: ${month.toString().padLeft(2, '0')}/$year';
        sheet.appendRow([TextCellValue(periodTitle)]);

        // Calculate total columns for merging
        final nextMonthDays = DateTime(
          month == 12 ? year + 1 : year,
          month == 12 ? 1 : month + 1,
          0,
        ).day;
        final totalCols =
            7 + daysInMonth + nextMonthDays - 1; // -1 for 0-based index

        // Merge title across all columns
        sheet.merge(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
          CellIndex.indexByColumnRow(columnIndex: totalCols, rowIndex: 0),
        );
        _stylePeriodTitle(sheet, 0);

        // ROW 1: Main headers + Month titles
        sheet.appendRow([
          TextCellValue('NO'),
          TextCellValue('JENIS RANMOR'),
          TextCellValue('NO POL'),
          TextCellValue('KODE'),
          TextCellValue('SATKER'),
          TextCellValue('KUOTA'),
          TextCellValue('KUOTA SISA'),
        ]);

        // Add month headers for current month
        var monthTitle = 'BULAN ${month.toString().padLeft(2, '0')} - $year';
        var startColIndex = 7; // Starting from column H (index 7)
        var currentMonthEndCol = startColIndex + daysInMonth - 1;

        // Style current month header (merge cells for month title)
        _styleMonthHeader(
          sheet,
          1, // Row 1 now (after title)
          startColIndex,
          currentMonthEndCol,
          monthTitle,
        );

        // Next month
        var nextMonth = month == 12 ? 1 : month + 1;
        var nextYear = month == 12 ? year + 1 : year;
        var nextMonthDaysCount = DateTime(nextYear, nextMonth + 1, 0).day;
        var nextMonthStartCol = currentMonthEndCol + 1;
        var nextMonthEndCol = nextMonthStartCol + nextMonthDaysCount - 1;

        monthTitle =
            'BULAN ${nextMonth.toString().padLeft(2, '0')} - $nextYear';

        // Style next month header
        _styleMonthHeader(
          sheet,
          1, // Row 1 now (after title)
          nextMonthStartCol,
          nextMonthEndCol,
          monthTitle,
        );

        // ROW 2: Sub-headers (dates)
        sheet.appendRow([
          TextCellValue(''),
          TextCellValue(''),
          TextCellValue(''),
          TextCellValue(''),
          TextCellValue(''),
          TextCellValue(''),
          TextCellValue(''),
        ]); // Empty cells for main columns

        // Add date numbers for current month (row 2)
        var colIndex = startColIndex;
        for (int day = 1; day <= daysInMonth; day++) {
          sheet.updateCell(
            CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: 2),
            TextCellValue(day.toString()),
          );
          colIndex++;
        }

        // Add date numbers for next month (row 2)
        for (int day = 1; day <= nextMonthDaysCount; day++) {
          sheet.updateCell(
            CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: 2),
            TextCellValue(day.toString()),
          );
          colIndex++;
        }

        // Style header rows
        _styleHeaderRow(sheet, 1, colIndex); // Main headers row
        _styleHeaderRow(sheet, 2, colIndex); // Date headers row

        // Merge cells for main column headers to span 2 rows (skip title row)
        for (int col = 0; col < 7; col++) {
          sheet.merge(
            CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 1),
            CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 2),
          );
        }
      }

      // Populate kupon data
      var ranPxData = kupons
          .where((k) => k.jenisKuponId == 1 && k.jenisBbmId == 1)
          .toList();
      var dukPxData = kupons
          .where((k) => k.jenisKuponId == 2 && k.jenisBbmId == 1)
          .toList();
      var ranDexData = kupons
          .where((k) => k.jenisKuponId == 1 && k.jenisBbmId == 2)
          .toList();
      var dukDexData = kupons
          .where((k) => k.jenisKuponId == 2 && k.jenisBbmId == 2)
          .toList();

      print('[EXPORT DEBUG] RAN.PX data: ${ranPxData.length}');
      print('[EXPORT DEBUG] DUK.PX data: ${dukPxData.length}');
      print('[EXPORT DEBUG] RAN.DEX data: ${ranDexData.length}');
      print('[EXPORT DEBUG] DUK.DEX data: ${dukDexData.length}');

      void populateSheet(
        Sheet sheet,
        List<KuponEntity> data,
        String sheetName,
      ) {
        print(
          '[EXPORT DEBUG] Populating $sheetName with ${data.length} records',
        );

        final int startRow = 3; // Start after title + 2-row header

        // Calculate total columns (7 basic + days from both months)
        final nextMonth = month == 12 ? 1 : month + 1;
        final nextYear = month == 12 ? year + 1 : year;
        final nextMonthDays = DateTime(nextYear, nextMonth + 1, 0).day;
        final totalCols = 7 + daysInMonth + nextMonthDays;

        for (int i = 0; i < data.length; i++) {
          final k = data[i];
          final kendaraan = _kendaraanList.firstWhere(
            (kend) => kend.kendaraanId == k.kendaraanId,
            orElse: () => KendaraanModel(
              kendaraanId: 0,
              satkerId: 0,
              jenisRanmor: '-',
              noPolKode: '-',
              noPolNomor: '-',
            ),
          );

          final currentRowIndex = startRow + i;

          // Basic data columns
          sheet.updateCell(
            CellIndex.indexByColumnRow(
              columnIndex: 0,
              rowIndex: currentRowIndex,
            ),
            IntCellValue(i + 1),
          );
          sheet.updateCell(
            CellIndex.indexByColumnRow(
              columnIndex: 1,
              rowIndex: currentRowIndex,
            ),
            TextCellValue(kendaraan.jenisRanmor),
          );
          sheet.updateCell(
            CellIndex.indexByColumnRow(
              columnIndex: 2,
              rowIndex: currentRowIndex,
            ),
            TextCellValue(kendaraan.noPolNomor),
          );
          sheet.updateCell(
            CellIndex.indexByColumnRow(
              columnIndex: 3,
              rowIndex: currentRowIndex,
            ),
            TextCellValue(kendaraan.noPolKode),
          );
          sheet.updateCell(
            CellIndex.indexByColumnRow(
              columnIndex: 4,
              rowIndex: currentRowIndex,
            ),
            TextCellValue(k.namaSatker),
          );
          sheet.updateCell(
            CellIndex.indexByColumnRow(
              columnIndex: 5,
              rowIndex: currentRowIndex,
            ),
            DoubleCellValue(k.kuotaAwal),
          );
          sheet.updateCell(
            CellIndex.indexByColumnRow(
              columnIndex: 6,
              rowIndex: currentRowIndex,
            ),
            DoubleCellValue(k.kuotaSisa),
          );

          // Fill transaction data per day - Current Month
          var colIndex = 7;
          for (int day = 1; day <= daysInMonth; day++) {
            final dateStr =
                '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

            // Get transactions for this kupon on this date
            final dayTransactions = transaksiProvider.transaksiList
                .where(
                  (t) =>
                      t.kuponId == k.kuponId &&
                      t.tanggalTransaksi.startsWith(dateStr) &&
                      t.isDeleted == 0,
                )
                .toList();

            final totalLiter = dayTransactions.fold(
              0.0,
              (sum, t) => sum + t.jumlahLiter,
            );

            if (totalLiter > 0) {
              sheet.updateCell(
                CellIndex.indexByColumnRow(
                  columnIndex: colIndex,
                  rowIndex: currentRowIndex,
                ),
                DoubleCellValue(totalLiter),
              );
            }
            colIndex++;
          }

          // Fill transaction data per day - Next Month
          for (int day = 1; day <= nextMonthDays; day++) {
            final dateStr =
                '$nextYear-${nextMonth.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

            // Get transactions for this kupon on this date
            final dayTransactions = transaksiProvider.transaksiList
                .where(
                  (t) =>
                      t.kuponId == k.kuponId &&
                      t.tanggalTransaksi.startsWith(dateStr) &&
                      t.isDeleted == 0,
                )
                .toList();

            final totalLiter = dayTransactions.fold(
              0.0,
              (sum, t) => sum + t.jumlahLiter,
            );

            if (totalLiter > 0) {
              sheet.updateCell(
                CellIndex.indexByColumnRow(
                  columnIndex: colIndex,
                  rowIndex: currentRowIndex,
                ),
                DoubleCellValue(totalLiter),
              );
            }
            colIndex++;
          }
        }

        // Apply styling to data rows
        if (data.isNotEmpty) {
          _styleDataRows(
            sheet,
            startRow,
            startRow + data.length - 1,
            totalCols,
          );
        }

        // Auto-resize columns
        _autoResizeColumns(sheet, totalCols);
      }

      // Populate all kupon sheets
      populateSheet(sheetRanPx, ranPxData, 'RAN.PX');
      populateSheet(sheetDukPx, dukPxData, 'DUK.PX');
      populateSheet(sheetDexPx, ranDexData, 'RAN.DEX');
      populateSheet(sheetDukDex, dukDexData, 'DUK.DEX');
    }

    // Handle satker export
    if (exportSatker) {
      // Create sheets for satker data
      sheetRekapPx = excel['REKAP.PX'];
      sheetRekapDx = excel['REKAP.DX'];

      // Setup both REKAP sheets with same styling structure
      for (var sheet in [sheetRekapPx, sheetRekapDx]) {
        // ROW 0: Title row with period
        final periodTitle =
            'Periode: ${month.toString().padLeft(2, '0')}/$year';
        sheet.appendRow([TextCellValue(periodTitle)]);

        // Merge title across all columns (5 columns for satker)
        sheet.merge(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
          CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 0),
        );
        _stylePeriodTitle(sheet, 0);

        // ROW 1: Headers
        sheet.appendRow([
          TextCellValue('NO'),
          TextCellValue('SATKER'),
          TextCellValue('KUOTA'),
          TextCellValue('PEMAKAIAN'),
          TextCellValue('SALDO'),
        ]);
        _styleHeaderRow(sheet, 1, 5);
      }

      // Handle satker data population
      if (exportSatker) {
        // Function to calculate totals and populate sheet
        void populateRekapSheet(Sheet sheet, bool isPertamax) {
          var index = 1;
          var currentRow = 2; // Start from row 2 (after title + header)
          double totalKuota = 0;
          double totalPemakaian = 0;
          double totalSaldo = 0;

          // Fixed satker order
          final List<String> satkerOrder = [
            'KAPOLDA',
            'WAKAPOLDA',
            'IRWASDA',
            'ROOPS',
            'RORENA',
            'RO SDM',
            'ROLOG',
            'DITINTELKAM',
            'DITKRIMUM',
            'DITKRIMSUS',
            'DITNARKOBA',
            'DITLANTAS',
            'DITBINMAS',
            'DITSAMAPTA',
            'DITPAMOBVIT',
            'DITPOLAIRUD',
            'SATBRIMOB',
            'BIDPROPAM',
            'BIDHUMAS',
            'BIDKUM',
            'BID TIK',
            'BIDDOKKES',
            'BIDKEU',
            'SPN',
            'DITRESSIBER',
            'DITLABFOR',
            'KOORPSPRIPIM',
            'YANMA',
            'SETUM',
            'SPKT',
            'DITTAHTI',
            'RUMAH SAKIT BHAYANGKARA SARTIKA ASIH (RSSA)',
            'RUMAH SAKIT BHAYANGKARA INDRAMAYU',
            'RUMAH SAKIT BHAYANGKARA BOGOR',
          ];

          // Calculate regular satker totals
          for (var satker in satkerOrder) {
            // Filter kupons for this satker, BBM type, and Ranjen only
            var satkerKupons = kupons
                .where(
                  (k) =>
                      k.namaSatker == satker &&
                      k.jenisBbmId == (isPertamax ? 1 : 2) &&
                      k.jenisKuponId == 1, // Only Ranjen
                )
                .toList();

            if (satkerKupons.isEmpty) continue;

            final kuota = satkerKupons.fold(0.0, (sum, k) => sum + k.kuotaAwal);
            final pemakaian = satkerKupons.fold(
              0.0,
              (sum, k) => sum + (k.kuotaAwal - k.kuotaSisa),
            );
            final saldo = kuota - pemakaian;

            // Update cells individually for better control
            sheet.updateCell(
              CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
              IntCellValue(index),
            );
            sheet.updateCell(
              CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow),
              TextCellValue(satker),
            );
            sheet.updateCell(
              CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow),
              DoubleCellValue(kuota),
            );
            sheet.updateCell(
              CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow),
              DoubleCellValue(pemakaian),
            );
            sheet.updateCell(
              CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow),
              DoubleCellValue(saldo),
            );

            totalKuota += kuota;
            totalPemakaian += pemakaian;
            totalSaldo += saldo;
            index++;
            currentRow++;
          }

          // Calculate Dukungan totals (jenisKuponId = 2)
          var dukunganKupons = kupons
              .where(
                (k) =>
                    k.jenisBbmId == (isPertamax ? 1 : 2) && k.jenisKuponId == 2,
              )
              .toList();

          if (dukunganKupons.isNotEmpty) {
            final dukunganKuota = dukunganKupons.fold(
              0.0,
              (sum, k) => sum + k.kuotaAwal,
            );
            final dukunganPemakaian = dukunganKupons.fold(
              0.0,
              (sum, k) => sum + (k.kuotaAwal - k.kuotaSisa),
            );
            final dukunganSaldo = dukunganKuota - dukunganPemakaian;

            // Add Dukungan row
            sheet.updateCell(
              CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
              IntCellValue(index),
            );
            sheet.updateCell(
              CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow),
              TextCellValue('DUKUNGAN'),
            );
            sheet.updateCell(
              CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow),
              DoubleCellValue(dukunganKuota),
            );
            sheet.updateCell(
              CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow),
              DoubleCellValue(dukunganPemakaian),
            );
            sheet.updateCell(
              CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow),
              DoubleCellValue(dukunganSaldo),
            );

            totalKuota += dukunganKuota;
            totalPemakaian += dukunganPemakaian;
            totalSaldo += dukunganSaldo;
            currentRow++;
          }

          // Add Grand Total row
          sheet.updateCell(
            CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
            TextCellValue(''),
          );
          sheet.updateCell(
            CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow),
            TextCellValue('GRAND TOTAL'),
          );
          sheet.updateCell(
            CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow),
            DoubleCellValue(totalKuota),
          );
          sheet.updateCell(
            CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow),
            DoubleCellValue(totalPemakaian),
          );
          sheet.updateCell(
            CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow),
            DoubleCellValue(totalSaldo),
          );

          // Apply styling to data rows (from row 2 to currentRow-1)
          if (currentRow > 2) {
            _styleDataRows(sheet, 2, currentRow - 1, 5);
          }

          // Style Grand Total row
          _styleTotalRow(sheet, currentRow, 5);

          // Auto-resize columns
          _autoResizeColumns(sheet, 5);
        }

        // Populate both sheets
        populateRekapSheet(sheetRekapPx, true); // For Pertamax
        populateRekapSheet(sheetRekapDx, false); // For Dex
      }
    }

    // Remove default sheet if exists
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    // Save dialog
    String? outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Simpan file Excel',
      fileName: 'export_kupon_${DateTime.now().millisecondsSinceEpoch}.xlsx',
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (outputPath == null) return;

    final fileBytes = excel.encode();
    if (fileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal membuat file Excel.')),
      );
      return;
    }
    final file = File(outputPath);
    await file.writeAsBytes(fileBytes, flush: true);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Export berhasil: $outputPath')));
  }

  // Helper functions for Excel styling
  void _styleHeaderRow(Sheet sheet, int rowIndex, int columnCount) {
    for (int col = 0; col < columnCount; col++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex),
      );

      cell.cellStyle = CellStyle(
        backgroundColorHex: ExcelColor.blue,
        fontColorHex: ExcelColor.white,
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
    }
  }

  void _styleDataRows(Sheet sheet, int startRow, int endRow, int columnCount) {
    for (int row = startRow; row <= endRow; row++) {
      for (int col = 0; col < columnCount; col++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
        );

        // Alternating row colors
        ExcelColor bgColor = row % 2 == 0 ? ExcelColor.white : ExcelColor.none;

        cell.cellStyle = CellStyle(
          backgroundColorHex: bgColor,
          horizontalAlign: col == 0
              ? HorizontalAlign.Center
              : (col >= 5 ? HorizontalAlign.Right : HorizontalAlign.Left),
          verticalAlign: VerticalAlign.Center,
        );
      }
    }
  }

  void _styleTotalRow(Sheet sheet, int rowIndex, int columnCount) {
    for (int col = 0; col < columnCount; col++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex),
      );

      cell.cellStyle = CellStyle(
        backgroundColorHex: ExcelColor.blue,
        fontColorHex: ExcelColor.white,
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
    }
  }

  void _styleMonthHeader(
    Sheet sheet,
    int rowIndex,
    int startCol,
    int endCol,
    String title,
  ) {
    // Merge cells for month title
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: startCol, rowIndex: rowIndex),
      CellIndex.indexByColumnRow(columnIndex: endCol, rowIndex: rowIndex),
    );

    final cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: startCol, rowIndex: rowIndex),
    );

    cell.value = TextCellValue(title);
    cell.cellStyle = CellStyle(
      backgroundColorHex: ExcelColor.green,
      fontColorHex: ExcelColor.white,
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
  }

  void _stylePeriodTitle(Sheet sheet, int rowIndex) {
    final cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
    );

    cell.cellStyle = CellStyle(
      backgroundColorHex: ExcelColor.blue,
      fontColorHex: ExcelColor.white,
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
  }

  void _autoResizeColumns(Sheet sheet, int columnCount) {
    // Set fixed column widths for better appearance
    const Map<int, double> columnWidths = {
      0: 5.0, // NO
      1: 15.0, // JENIS RANMOR or SATKER
      2: 10.0, // NO POL or KUOTA
      3: 8.0, // KODE or PEMAKAIAN
      4: 20.0, // SATKER or SALDO
      5: 12.0, // KUOTA
      6: 12.0, // KUOTA SISA
    };

    for (int col = 0; col < columnCount; col++) {
      if (columnWidths.containsKey(col)) {
        sheet.setColumnWidth(col, columnWidths[col]!);
      } else {
        // For date columns, make them smaller
        sheet.setColumnWidth(col, 4.0);
      }
    }
  }
}

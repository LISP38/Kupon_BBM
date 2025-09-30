import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
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
            const Text(
              'Filter',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                // Nomor Kupon Filter
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _nomorKuponController,
                    decoration: const InputDecoration(
                      labelText: 'Nomor Kupon',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.numbers),
                    ),
                  ),
                ),

                // Satker Filter
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    value: _selectedSatker,
                    items: provider.kupons
                        .map((k) => k.namaSatker)
                        .toSet()
                        .map(
                          (namaSatker) => DropdownMenuItem(
                            value: namaSatker,
                            child: Text(namaSatker),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => _selectedSatker = val),
                    decoration: const InputDecoration(
                      labelText: 'Satker',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business),
                    ),
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
                  child: TextField(
                    controller: _nopolController,
                    decoration: const InputDecoration(
                      labelText: 'Nomor Polisi',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.directions_car),
                    ),
                  ),
                ),

                // Jenis Ranmor Filter
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    value: _selectedJenisRanmor,
                    items: _kendaraanList
                        .map((k) => k.jenisRanmor)
                        .toSet()
                        .map(
                          (jenis) => DropdownMenuItem(
                            value: jenis,
                            child: Text(jenis),
                          ),
                        )
                        .toList(),
                    onChanged: (val) =>
                        setState(() => _selectedJenisRanmor = val),
                    decoration: const InputDecoration(
                      labelText: 'Jenis Ranmor',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category),
                    ),
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
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () {
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
                  label: const Text('Cari'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    _nomorKuponController.clear();
                    _nopolController.clear();
                    setState(() {
                      _selectedSatker = null;
                      _selectedJenisBBM = null;
                      _selectedJenisKupon = null;
                      _selectedJenisRanmor = null;
                      _selectedBulan = null;
                      _selectedTahun = null;
                    });
                    provider.fetchKupons();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset'),
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
        final kupons = provider.kupons;
        if (kupons.isEmpty) {
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
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
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
                rows: kupons.asMap().entries.map((entry) {
                  final i = entry.key + 1;
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
                          _jenisBBMMap[k.jenisBbmId] ?? k.jenisBbmId.toString(),
                        ),
                      ),
                      DataCell(
                        Text(
                          _jenisKuponMap[k.jenisKuponId] ??
                              k.jenisKuponId.toString(),
                        ),
                      ),
                      DataCell(Text(_getNopolByKendaraanId(k.kendaraanId))),
                      DataCell(Text(k.kuotaAwal.toString())),
                      DataCell(Text(k.kuotaSisa.toString())),
                      DataCell(Text(k.status)),
                      DataCell(
                        IconButton(
                          icon: const Icon(Icons.info_outline),
                          onPressed: () =>
                              _showKuponDetailDialog(context, k, kendaraan),
                          tooltip: 'Detail',
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
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
    final kupons = provider.kupons;
    if (kupons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada data untuk diexport.')),
      );
      return;
    }

    final excel = Excel.createExcel();

    // Create sheets based on export type
    late final Sheet sheetRanPx;
    late final Sheet sheetDukPx;
    late final Sheet sheetDexPx;
    late final Sheet sheetDukDex;
    late final Sheet sheetRekapPx;
    late final Sheet sheetRekapDx;

    if (exportKupon) {
      // Create 4 sheets for kupon data
      sheetRanPx = excel['RAN.PX'];
      sheetDukPx = excel['DUK.PX'];
      sheetDexPx = excel['RAN.DEX'];
      sheetDukDex = excel['DUK.DEX'];
    }

    if (exportSatker) {
      // Create sheets for satker data
      sheetRekapPx = excel['REKAP.PX'];
      sheetRekapDx = excel['REKAP.DX'];

      // Add headers for Rekap Pertamax sheet
      sheetRekapPx.appendRow([
        TextCellValue('NO'),
        TextCellValue('SATKER'),
        TextCellValue('KUOTA'),
        TextCellValue('PEMAKAIAN'),
        TextCellValue('SALDO'),
      ]);

      // Add headers for Rekap Dex sheet
      sheetRekapDx.appendRow([
        TextCellValue('NO'),
        TextCellValue('SATKER'),
        TextCellValue('KUOTA'),
        TextCellValue('PEMAKAIAN'),
        TextCellValue('SALDO'),
      ]);

      // Calculate days in month
      final daysInMonth = DateTime(year, month + 1, 0).day;

      // Header structure for all sheets
      for (var sheet in [sheetRanPx, sheetDukPx, sheetDexPx, sheetDukDex]) {
        sheet.appendRow([
          TextCellValue('NO'),
          TextCellValue('JENIS RANMOR'),
          TextCellValue('NO POL'),
          TextCellValue('KODE'),
          TextCellValue('SATKER'),
          TextCellValue('KUOTA'),
          TextCellValue('KUOTA SISA'),
        ]);

        // Add date columns for current month
        var monthTitle = 'BULAN ${month.toString().padLeft(2, '0')} - $year';
        sheet.updateCell(
          CellIndex.indexByString("H1"),
          TextCellValue(monthTitle),
        );

        // Add date columns
        var colIndex = 8; // Starting from column H
        for (int day = 1; day <= daysInMonth; day++) {
          sheet.updateCell(
            CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: 0),
            TextCellValue(day.toString()),
          );
          colIndex++;
        }

        // Next month
        var nextMonth = month == 12 ? 1 : month + 1;
        var nextYear = month == 12 ? year + 1 : year;
        var nextMonthDays = DateTime(nextYear, nextMonth + 1, 0).day;

        monthTitle =
            'BULAN ${nextMonth.toString().padLeft(2, '0')} - $nextYear';
        sheet.updateCell(
          CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: 0),
          TextCellValue(monthTitle),
        );
        colIndex++;

        for (int day = 1; day <= nextMonthDays; day++) {
          sheet.updateCell(
            CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: 0),
            TextCellValue(day.toString()),
          );
          colIndex++;
        }
      }

      // Populate data
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

      void populateSheet(Sheet sheet, List<KuponEntity> data) {
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

          sheet.appendRow([
            IntCellValue(i + 1),
            TextCellValue(kendaraan.jenisRanmor),
            TextCellValue(kendaraan.noPolNomor),
            TextCellValue(kendaraan.noPolKode),
            TextCellValue(k.namaSatker),
            DoubleCellValue(k.kuotaAwal),
            DoubleCellValue(k.kuotaSisa),
          ]);
        }
      }

      if (exportKupon) {
        populateSheet(sheetRanPx, ranPxData);
        populateSheet(sheetDukPx, dukPxData);
        populateSheet(sheetDexPx, ranDexData);
        populateSheet(sheetDukDex, dukDexData);
      }

      if (exportSatker) {
        // Create sheets for satker data
        final sheetRekapPx = excel['REKAP.PX'];
        final sheetRekapDx = excel['REKAP.DX'];

        // Add headers for both sheets
        for (var sheet in [sheetRekapPx, sheetRekapDx]) {
          sheet.appendRow([
            TextCellValue('NO'),
            TextCellValue('SATKER'),
            TextCellValue('KUOTA'),
            TextCellValue('PEMAKAIAN'),
            TextCellValue('SALDO'),
          ]);
        }

        // Function to calculate totals and populate sheet
        void populateRekapSheet(Sheet sheet, bool isPertamax) {
          var index = 1;
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

            sheet.appendRow([
              IntCellValue(index),
              TextCellValue(satker),
              DoubleCellValue(kuota),
              DoubleCellValue(pemakaian),
              DoubleCellValue(saldo),
            ]);

            totalKuota += kuota;
            totalPemakaian += pemakaian;
            totalSaldo += saldo;
            index++;
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
            sheet.appendRow([
              IntCellValue(index),
              TextCellValue('DUKUNGAN'),
              DoubleCellValue(dukunganKuota),
              DoubleCellValue(dukunganPemakaian),
              DoubleCellValue(dukunganSaldo),
            ]);

            totalKuota += dukunganKuota;
            totalPemakaian += dukunganPemakaian;
            totalSaldo += dukunganSaldo;
          }

          // Add Grand Total row
          sheet.appendRow([
            TextCellValue(''),
            TextCellValue('GRAND TOTAL'),
            DoubleCellValue(totalKuota),
            DoubleCellValue(totalPemakaian),
            DoubleCellValue(totalSaldo),
          ]);
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
}

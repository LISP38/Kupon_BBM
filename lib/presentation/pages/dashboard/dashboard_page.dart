import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../../core/di/dependency_injection.dart';
import 'package:kupon_bbm_app/domain/repositories/kendaraan_repository.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../../domain/entities/kendaraan_entity.dart';
import 'package:kupon_bbm_app/data/models/kendaraan_model.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
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
                  style: TextStyle(fontSize: 18, color: Colors.blue.shade900, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  bool _firstLoad = true;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Auto-refresh data setiap kali tab dashboard muncul
    if (_firstLoad) {
      Provider.of<DashboardProvider>(context, listen: false).fetchKupons();
      _firstLoad = false;
    }
  }
  // Filter controllers
  final TextEditingController _nomorKuponController = TextEditingController();
  final TextEditingController _nopolController = TextEditingController();
  String? _selectedSatker;
  String? _selectedJenisBBM;
  String? _selectedJenisKupon;
  int? _selectedBulan;
  int? _selectedTahun;

  final Map<int, String> _satkerMap = {
    1: 'KAPOLDA',
    2: 'WAKAPOLDA',
    3: 'IRWASDA',
    4: 'SATKER LAIN'
    // ...lengkapi sesuai master data
  };
  final Map<int, String> _jenisBBMMap = {1: 'Pertamax', 2: 'Pertamina Dex'};
  final Map<int, String> _jenisKuponMap = {1: 'Ranjen', 2: 'Dukungan'};

  final List<int> _bulanList = List.generate(12, (i) => i + 1);
  final List<int> _tahunList = [2024, 2025]; // TODO: Dynamic tahun

  List<KendaraanEntity> _kendaraanList = [];

  @override
  void initState() {
    super.initState();
    _fetchKendaraanList();
  }

  Future<void> _fetchKendaraanList() async {
    final repo = getIt<KendaraanRepository>();
    _kendaraanList = await repo.getAllKendaraan();
    setState(() {});
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
    return ChangeNotifierProvider(
      create: (_) => DashboardProvider(getIt.get()),
      child: Scaffold(
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
                  Provider.of<DashboardProvider>(context, listen: false).fetchKupons();
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
                  onPressed: () async {
                    await _exportToExcel(context);
                  },
                  icon: const Icon(Icons.download),
                  label: const Text('Export Data'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: _nomorKuponController,
                    decoration: const InputDecoration(
                      labelText: 'Nomor Kupon',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    value: _selectedSatker,
                    items: _satkerMap.entries.map((e) => DropdownMenuItem(value: e.value, child: Text(e.value))).toList(),
                    onChanged: (val) => setState(() => _selectedSatker = val),
                    decoration: const InputDecoration(labelText: 'Satker', border: OutlineInputBorder()),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    value: _selectedJenisBBM,
                    items: _jenisBBMMap.entries.map((e) => DropdownMenuItem(value: e.value, child: Text(e.value))).toList(),
                    onChanged: (val) => setState(() => _selectedJenisBBM = val),
                    decoration: const InputDecoration(labelText: 'Jenis BBM', border: OutlineInputBorder()),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    value: _selectedJenisKupon,
                    items: _jenisKuponMap.entries.map((e) => DropdownMenuItem(value: e.value, child: Text(e.value))).toList(),
                    onChanged: (val) => setState(() => _selectedJenisKupon = val),
                    decoration: const InputDecoration(labelText: 'Jenis Kupon', border: OutlineInputBorder()),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: _nopolController,
                    decoration: const InputDecoration(
                      labelText: 'NoPol',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: DropdownButtonFormField<int>(
                    value: _selectedBulan,
                    items: _bulanList.map((e) => DropdownMenuItem(value: e, child: Text(e.toString()))).toList(),
                    onChanged: (val) => setState(() => _selectedBulan = val),
                    decoration: const InputDecoration(labelText: 'Bulan', border: OutlineInputBorder()),
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: DropdownButtonFormField<int>(
                    value: _selectedTahun,
                    items: _tahunList.map((e) => DropdownMenuItem(value: e, child: Text(e.toString()))).toList(),
                    onChanged: (val) => setState(() => _selectedTahun = val),
                    decoration: const InputDecoration(labelText: 'Tahun', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
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

  Widget _buildMasterKuponTable(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, provider, _) {
        final kupons = provider.kupons;
        if (kupons.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text('Data tidak ditemukan', style: TextStyle(fontSize: 18)),
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
                  DataColumn(label: Text('Satker')),
                  DataColumn(label: Text('Jenis BBM')),
                  DataColumn(label: Text('Jenis Kupon')),
                  DataColumn(label: Text('NoPol')),
                  DataColumn(label: Text('Bulan/Tahun')),
                  DataColumn(label: Text('Kuota Sisa')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Detail')),
                ],
                rows: kupons.asMap().entries.map((entry) {
                  final i = entry.key + 1;
                  final k = entry.value;
                  return DataRow(cells: [
                    DataCell(Text(i.toString())),
                    DataCell(Text(k.nomorKupon)),
                    DataCell(Text(_satkerMap[k.kendaraanId] ?? k.kendaraanId.toString())),
                    DataCell(Text(_jenisBBMMap[k.jenisBbmId] ?? k.jenisBbmId.toString())),
                    DataCell(Text(_jenisKuponMap[k.jenisKuponId] ?? k.jenisKuponId.toString())),
                    DataCell(Text(_getNopolByKendaraanId(k.kendaraanId))),
                    DataCell(Text('${k.bulanTerbit}/${k.tahunTerbit}')),
                    DataCell(Text(k.kuotaSisa.toString())),
                    DataCell(Text(k.status)),
                    DataCell(IconButton(
                      icon: const Icon(Icons.info_outline),
                      onPressed: () {
                        // TODO: tampilkan detail kupon
                      },
                    )),
                  ]);
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _exportToExcel(BuildContext context) async {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final kupons = provider.kupons;
    if (kupons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada data untuk diexport.')),
      );
      return;
    }

    final excel = Excel.createExcel();
    final sheet = excel['Kupon'];
    // Header
    sheet.appendRow([
      TextCellValue('No'),
      TextCellValue('Nomor Kupon'),
      TextCellValue('Jenis Kupon'),
      TextCellValue('Jenis BBM'),
      TextCellValue('Nomor Polisi'),
      TextCellValue('Kuota Awal'),
      TextCellValue('Kuota Sisa'),
      TextCellValue('Periode'),
      TextCellValue('Status'),
    ]);
    // Data
    for (int i = 0; i < kupons.length; i++) {
      final k = kupons[i];
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
        TextCellValue(k.nomorKupon),
        TextCellValue(_jenisKuponMap[k.jenisKuponId] ?? k.jenisKuponId.toString()),
        TextCellValue(_jenisBBMMap[k.jenisBbmId] ?? k.jenisBbmId.toString()),
        TextCellValue('${kendaraan.noPolNomor}-${kendaraan.noPolKode}'),
        DoubleCellValue(k.kuotaAwal),
        DoubleCellValue(k.kuotaSisa),
        TextCellValue('${k.bulanTerbit}/${k.tahunTerbit}'),
        TextCellValue(k.status),
      ]);
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Export berhasil: $outputPath')),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/transaksi_provider.dart';
import '../../../core/di/dependency_injection.dart';
import '../../../domain/entities/kendaraan_entity.dart';
import '../../../data/models/kendaraan_model.dart';
import '../../../domain/repositories/kendaraan_repository.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // Filter state
  int? _selectedBulan;
  int? _selectedTahun;

  final List<int> _bulanList = List.generate(12, (i) => i + 1);
  final List<int> _tahunList = [DateTime.now().year, DateTime.now().year + 1];

  List<KendaraanEntity> _kendaraanList = [];

  // Map jenis BBM untuk tampilan
  final Map<int, String> _jenisBBMMap = {1: 'Pertamax', 2: 'Pertamina Dex'};

  // Map jenis kupon untuk tampilan
  final Map<int, String> _jenisKuponMap = {1: 'Ranjen', 2: 'Dukungan'};

  // Mendapatkan NoPol dari kendaraanId
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
    return '${kendaraan.noPolNomor}-${kendaraan.noPolKode}';
  }

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final repo = getIt<KendaraanRepository>();
    final kendaraanList = await repo.getAllKendaraan();
    setState(() {
      _kendaraanList = kendaraanList;
    });
  }

  String _getBulanName(int bulan) {
    final namaBulan = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return namaBulan[bulan - 1];
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButton<int>(
                        isExpanded: true,
                        value: _selectedBulan,
                        hint: const Text('Pilih Bulan'),
                        items: _bulanList.map((bulan) {
                          return DropdownMenuItem<int>(
                            value: bulan,
                            child: Text(_getBulanName(bulan)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedBulan = value;
                          });
                          Provider.of<TransaksiProvider>(
                            context,
                            listen: false,
                          ).setBulan(value!);
                          Provider.of<TransaksiProvider>(
                            context,
                            listen: false,
                          ).fetchTransaksiFiltered();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<int>(
                        isExpanded: true,
                        value: _selectedTahun,
                        hint: const Text('Pilih Tahun'),
                        items: _tahunList.map((tahun) {
                          return DropdownMenuItem<int>(
                            value: tahun,
                            child: Text(tahun.toString()),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedTahun = value;
                          });
                          Provider.of<TransaksiProvider>(
                            context,
                            listen: false,
                          ).setTahun(value!);
                          Provider.of<TransaksiProvider>(
                            context,
                            listen: false,
                          ).fetchTransaksiFiltered();
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedBulan = null;
                          _selectedTahun = null;
                        });
                        Provider.of<TransaksiProvider>(
                          context,
                          listen: false,
                        ).resetFilter();
                        Provider.of<TransaksiProvider>(
                          context,
                          listen: false,
                        ).fetchTransaksiFiltered();
                        Provider.of<TransaksiProvider>(
                          context,
                          listen: false,
                        ).fetchKuponMinus();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset Filter'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransaksiTable(BuildContext context) {
    return Consumer<TransaksiProvider>(
      builder: (context, provider, _) {
        final transaksi = provider.transaksiList;

        if (transaksi.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text(
                'Tidak ada data transaksi',
                style: TextStyle(fontSize: 18),
              ),
            ),
          );
        }

        return Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Tanggal')),
                DataColumn(label: Text('Nomor Kupon')),
                DataColumn(label: Text('Jenis BBM')),
                DataColumn(label: Text('Jumlah (L)')),
                DataColumn(label: Text('Status')),
              ],
              rows: transaksi
                  .map(
                    (t) => DataRow(
                      cells: [
                        DataCell(Text(t.tanggalTransaksi)),
                        DataCell(Text(t.nomorKupon)),
                        DataCell(
                          Text(
                            t.jenisBbm == '1' ? 'Pertamax' : 'Pertamina Dex',
                          ),
                        ),
                        DataCell(Text(t.jumlahDiambil.toString())),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: t.status == 'completed'
                                  ? Colors.green
                                  : Colors.blue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              t.status == 'completed' ? 'Selesai' : 'Proses',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        );
      },
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
                  DataColumn(label: Text('Satker')),
                  DataColumn(label: Text('Jenis BBM')),
                  DataColumn(label: Text('Jenis Kupon')),
                  DataColumn(label: Text('NoPol')),
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
                      DataCell(Text(k.nomorKupon)),
                      DataCell(Text(k.namaSatker)),
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
                      DataCell(Text('${k.bulanTerbit}/${k.tahunTerbit}')),
                      DataCell(Text(k.kuotaSisa.toString())),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: k.status == 'available'
                                ? Colors.blue
                                : k.status == 'used'
                                ? Colors.green
                                : Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            k.status == 'available'
                                ? 'Tersedia'
                                : k.status == 'used'
                                ? 'Digunakan'
                                : 'Void',
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFilterSection(),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'Data Transaksi BBM',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(child: _buildTransaksiTable(context)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'Data Kupon',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(child: _buildMasterKuponTable(context)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

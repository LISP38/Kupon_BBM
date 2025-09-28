import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/transaksi_provider.dart';
import '../../../core/di/dependency_injection.dart';
import 'package:kupon_bbm_app/domain/repositories/kendaraan_repository.dart';
import '../../../domain/entities/kendaraan_entity.dart';
import '../../../data/models/kendaraan_model.dart';
import '../transaksi/transaksi_bbm_form_new.dart';

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get initial data
    Provider.of<DashboardProvider>(context, listen: false).fetchKupons();
    Provider.of<TransaksiProvider>(
      context,
      listen: false,
    ).fetchTransaksiFiltered();
  }

  Future<void> _initData() async {
    final repo = getIt<KendaraanRepository>();
    final kendaraanList = await repo.getAllKendaraan();
    if (mounted) {
      setState(() {
        _kendaraanList = kendaraanList;
      });
    }
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

  Widget _buildStatisticsCard() {
    return Consumer2<DashboardProvider, TransaksiProvider>(
      builder: (context, dashboardProvider, transaksiProvider, _) {
        // Langsung gunakan data dari provider tanpa mengubah state
        final totalKupon = dashboardProvider.kupons.length;
        final totalPertamax = dashboardProvider.kupons
            .where((k) => k.jenisBbmId == 1)
            .length;
        final totalDexlite = dashboardProvider.kupons
            .where((k) => k.jenisBbmId == 2)
            .length;
        final totalRanjen = dashboardProvider.kupons
            .where((k) => k.jenisKuponId == 1)
            .length;
        final totalDukungan = dashboardProvider.kupons
            .where((k) => k.jenisKuponId == 2)
            .length;
        final totalTransaksi = transaksiProvider.transaksiList.length;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Kupon',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatisticItem(
                      'Total Kupon',
                      totalKupon,
                      Icons.confirmation_number,
                    ),
                    _buildStatisticItem(
                      'Pertamax',
                      totalPertamax,
                      Icons.local_gas_station,
                    ),
                    _buildStatisticItem(
                      'Dexlite',
                      totalDexlite,
                      Icons.local_gas_station,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatisticItem(
                      'Ranjen',
                      totalRanjen,
                      Icons.military_tech,
                    ),
                    _buildStatisticItem(
                      'Dukungan',
                      totalDukungan,
                      Icons.support,
                    ),
                    _buildStatisticItem(
                      'Transaksi',
                      totalTransaksi,
                      Icons.receipt_long,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatisticItem(String label, int value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 32, color: Theme.of(context).primaryColor),
        const SizedBox(height: 8),
        Text(
          value.toString(),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
      ],
    );
  }

  Widget _buildFilterSection() {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: DropdownButton<int>(
                            isExpanded: true,
                            value: _selectedBulan,
                            hint: const Text('Pilih Bulan'),
                            underline: Container(),
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
                              if (value != null) {
                                Provider.of<TransaksiProvider>(
                                  context,
                                  listen: false,
                                ).setBulan(value);
                                Provider.of<TransaksiProvider>(
                                  context,
                                  listen: false,
                                ).fetchTransaksiFiltered();
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: DropdownButton<int>(
                            isExpanded: true,
                            value: _selectedTahun,
                            hint: const Text('Pilih Tahun'),
                            underline: Container(),
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
                              if (value != null) {
                                Provider.of<TransaksiProvider>(
                                  context,
                                  listen: false,
                                ).setTahun(value);
                                Provider.of<TransaksiProvider>(
                                  context,
                                  listen: false,
                                ).fetchTransaksiFiltered();
                              }
                            },
                          ),
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
                          // TODO: Implement search
                        },
                        icon: const Icon(Icons.search),
                        label: const Text('Search'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
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
                        label: const Text('Reset'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          foregroundColor: Colors.black87,
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

        return SingleChildScrollView(
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
                        Text(t.jenisBbm == '1' ? 'Pertamax' : 'Pertamina Dex'),
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
        );
      },
    );
  }

  Widget _buildMinusTable(BuildContext context) {
    return Consumer<TransaksiProvider>(
      builder: (context, provider, _) {
        final minusData = provider.kuponMinusList;
        if (minusData.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Tidak ada data minus',
                style: TextStyle(fontSize: 18),
              ),
            ),
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('No.')),
              DataColumn(label: Text('NoPol')),
              DataColumn(label: Text('Satker')),
              DataColumn(label: Text('Jenis BBM')),
              DataColumn(label: Text('Jumlah Minus')),
              DataColumn(label: Text('Status')),
            ],
            rows: minusData.asMap().entries.map((entry) {
              final i = entry.key + 1;
              final m = entry.value;
              return DataRow(
                cells: [
                  DataCell(Text(i.toString())),
                  DataCell(
                    Text(_getNopolByKendaraanId(m['kendaraan_id'] as int)),
                  ),
                  DataCell(Text(m['nama_satker'] as String)),
                  DataCell(
                    Text(
                      _jenisBBMMap[m['jenis_bbm_id'] as int] ??
                          (m['jenis_bbm_id'] as int).toString(),
                    ),
                  ),
                  DataCell(Text((m['minus_amount'] as int).toString())),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Minus',
                        style: TextStyle(color: Colors.white),
                      ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Statistics Card Section
            _buildStatisticsCard(),
            const SizedBox(height: 16),
            // Filter Section
            _buildFilterSection(),
            const SizedBox(height: 16),
            // Transaction Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TransaksiBBMForm(
                            jenisBbmId: 1,
                            jenisBbmName: 'Pertamax',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.local_gas_station),
                    label: const Text('Pertamax'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TransaksiBBMForm(
                            jenisBbmId: 2,
                            jenisBbmName: 'Dexlite',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.local_gas_station),
                    label: const Text('Dexlite'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Transaction Table Section
            Container(
              height: 400,
              child: Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Data Transaksi BBM',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              // TODO: Implement export
                            },
                            icon: const Icon(Icons.download),
                            label: const Text('Export'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: _buildTransaksiTable(context)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Minus Table
            Container(
              height: 300,
              child: Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Data Minus',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              // TODO: Implement minus data export
                            },
                            icon: const Icon(Icons.download),
                            label: const Text('Export'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: _buildMinusTable(context)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

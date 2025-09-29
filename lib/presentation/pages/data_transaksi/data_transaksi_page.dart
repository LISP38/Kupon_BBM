import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/di/dependency_injection.dart';
import '../../../domain/entities/kendaraan_entity.dart';
import '../../../domain/repositories/kendaraan_repository.dart';
import '../../../data/models/kendaraan_model.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/transaksi_provider.dart';
import '../transaksi/transaksi_bbm_form_new.dart';

class DataTransaksiPage extends StatefulWidget {
  const DataTransaksiPage({super.key});

  @override
  State<DataTransaksiPage> createState() => _DataTransaksiPageState();
}

class _DataTransaksiPageState extends State<DataTransaksiPage> {
  int? _selectedBulan;
  int? _selectedTahun;

  final List<int> _bulanList = List.generate(12, (i) => i + 1);
  final List<int> _tahunList = [DateTime.now().year, DateTime.now().year + 1];

  List<KendaraanEntity> _kendaraanList = [];

  // Map jenis BBM untuk tampilan
  final Map<int, String> _jenisBBMMap = {1: 'Pertamax', 2: 'Pertamina Dex'};

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
                        label: const Text('Cari'),
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
              DataColumn(label: Text('Satker')),
              DataColumn(label: Text('Jenis BBM')),
              DataColumn(label: Text('Jenis Kupon')),
              DataColumn(label: Text('Jumlah (L)')),
              DataColumn(label: Text('Aksi')),
            ],
            rows: transaksi.map((t) {
              return DataRow(
                cells: [
                  DataCell(Text(t.tanggalTransaksi)),
                  DataCell(Text(t.nomorKupon)),
                  DataCell(Text(t.namaSatker)),
                  DataCell(Text(_jenisBBMMap[t.jenisBbmId] ?? 'Unknown')),
                  DataCell(Text('RANJEN')),
                  DataCell(Text(t.jumlahLiter.toString())),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () async {
                            // TODO: Implement edit
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () async {
                            // TODO: Implement delete
                          },
                        ),
                      ],
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
      appBar: AppBar(
        title: const Text('Data Transaksi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: () {
              // TODO: Implement export
            },
            tooltip: 'Export Transaksi',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildTransaksiTable(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

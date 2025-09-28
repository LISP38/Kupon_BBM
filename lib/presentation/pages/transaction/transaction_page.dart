import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import '../../providers/transaksi_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../../data/models/transaksi_model.dart';
import '../../../domain/entities/kupon_entity.dart';

class TransactionPage extends StatefulWidget {
  const TransactionPage({super.key});

  @override
  State<TransactionPage> createState() => _TransactionPageState();
}

class _TransactionPageState extends State<TransactionPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      Provider.of<TransaksiProvider>(
        context,
        listen: false,
      ).fetchTransaksiFiltered();
      Provider.of<TransaksiProvider>(context, listen: false).fetchKuponMinus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data Transaksi')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // FILTER SECTION
            Row(
              children: [
                SizedBox(
                  width: 180,
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Nomor Kupon',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      Provider.of<TransaksiProvider>(
                        context,
                        listen: false,
                      ).setFilterTransaksi(nomorKupon: val);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 180,
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Satker',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      Provider.of<TransaksiProvider>(
                        context,
                        listen: false,
                      ).setFilterTransaksi(satker: val);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Jenis BBM',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('Pertamax')),
                      DropdownMenuItem(value: 2, child: Text('Dex')),
                    ],
                    onChanged: (val) {
                      Provider.of<TransaksiProvider>(
                        context,
                        listen: false,
                      ).setFilterTransaksi(jenisBbmId: val);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 120,
                  child: DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Hari',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(
                      31,
                      (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text((i + 1).toString()),
                      ),
                    ),
                    onChanged: (val) {
                      Provider.of<TransaksiProvider>(
                        context,
                        listen: false,
                      ).setFilterTransaksi(hari: val);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 120,
                  child: DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Bulan',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(
                      12,
                      (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text((i + 1).toString()),
                      ),
                    ),
                    onChanged: (val) {
                      Provider.of<TransaksiProvider>(
                        context,
                        listen: false,
                      ).setFilterTransaksi(bulan: val);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 120,
                  child: DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Tahun',
                      border: OutlineInputBorder(),
                    ),
                    items: [2024, 2025]
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(e.toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      Provider.of<TransaksiProvider>(
                        context,
                        listen: false,
                      ).setFilterTransaksi(tahun: val);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    Provider.of<TransaksiProvider>(
                      context,
                      listen: false,
                    ).fetchTransaksiFiltered();
                  },
                  icon: const Icon(Icons.search),
                  label: const Text('Cari'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Data Transaksi',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _exportTransaksi,
                  icon: const Icon(Icons.download),
                  label: const Text('Export Transaksi'),
                ),
                ElevatedButton.icon(
                  onPressed: () =>
                      _showTambahTransaksiDialog(context, jenisBbm: 1),
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah Pertamax'),
                ),
                ElevatedButton.icon(
                  onPressed: () =>
                      _showTambahTransaksiDialog(context, jenisBbm: 2),
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah Dex'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildTransaksiTable(context)),
            const SizedBox(height: 16),
            const Text(
              'Kupon Minus',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Expanded(child: _buildKuponMinusTable(context)),
          ],
        ),
      ),
    );
  }

  void _exportTransaksi() async {
    final provider = Provider.of<TransaksiProvider>(context, listen: false);
    final transaksi = provider.transaksiList;
    if (transaksi.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak ada data transaksi untuk diexport.'),
        ),
      );
      return;
    }
    final excel = Excel.createExcel();
    final sheet = excel['Transaksi'];
    sheet.appendRow([
      TextCellValue('Tanggal'),
      TextCellValue('Nomor Kupon'),
      TextCellValue('Jenis BBM'),
      TextCellValue('Jumlah (L)'),
    ]);
    for (final t in transaksi) {
      sheet.appendRow([
        TextCellValue(t.tanggalTransaksi),
        TextCellValue(t.nomorKupon),
        TextCellValue(t.jenisBbmId.toString()),
        DoubleCellValue(t.jumlahDiambil?.toDouble() ?? 0),
      ]);
    }
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }
    String? outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Simpan file Excel',
      fileName:
          'export_transaksi_${DateTime.now().millisecondsSinceEpoch}.xlsx',
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

  Future<void> _showTambahTransaksiDialog(
    BuildContext context, {
    required int jenisBbm,
  }) async {
    final dashboardProvider = Provider.of<DashboardProvider>(
      context,
      listen: false,
    );
    final transaksiProvider = Provider.of<TransaksiProvider>(
      context,
      listen: false,
    );
    // Filter kuponList sesuai jenisBbm
    final List<KuponEntity> kuponList = dashboardProvider.kuponList
        .where((k) => k.jenisBbmId == jenisBbm)
        .toList();
    final List<String> kuponOptions = kuponList
        .map(
          (k) =>
              '${k.nomorKupon}/${k.bulanTerbit}/${k.tahunTerbit}/${k.namaSatker}',
        )
        .toList();
    final _formKey = GlobalKey<FormState>();
    final _tanggalController = TextEditingController(
      text: DateTime.now().toIso8601String().substring(0, 10),
    );
    String? _nomorKupon;
    double? _jumlahLiter;
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Tambah Transaksi'),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _tanggalController,
                  decoration: InputDecoration(labelText: 'Tanggal'),
                  readOnly: true,
                ),
                Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    return kuponOptions.where(
                      (option) => option.contains(textEditingValue.text),
                    );
                  },
                  onSelected: (value) {
                    _nomorKupon = value;
                  },
                  fieldViewBuilder:
                      (context, controller, focusNode, onFieldSubmitted) {
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: InputDecoration(labelText: 'Nomor Kupon'),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Pilih nomor kupon'
                              : null,
                        );
                      },
                ),
                TextFormField(
                  decoration: InputDecoration(labelText: 'Jumlah Liter'),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    _jumlahLiter = double.tryParse(value);
                  },
                  validator: (value) => value == null || value.isEmpty
                      ? 'Masukkan jumlah liter'
                      : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!_formKey.currentState!.validate()) return;
                KuponEntity? kupon;
                for (final k in kuponList) {
                  final formatLengkap =
                      '${k.nomorKupon}/${k.bulanTerbit}/${k.tahunTerbit}/${k.namaSatker}';
                  if (formatLengkap == _nomorKupon) {
                    kupon = k;
                    break;
                  }
                }
                if (kupon == null || kupon.kuponId <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kupon tidak ditemukan!')),
                  );
                  return;
                }
                if (kupon.kuotaSisa < (_jumlahLiter ?? 0)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kuota tidak cukup!')),
                  );
                  return;
                }
                final transaksiBaru = TransaksiModel(
                  transaksiId: 0,
                  kuponId: kupon.kuponId,
                  nomorKupon: kupon.nomorKupon,
                  namaSatker: kupon.namaSatker,
                  jenisBbmId: jenisBbm,
                  tanggalTransaksi: _tanggalController.text,
                  jumlahLiter: _jumlahLiter?.toDouble() ?? 0,
                  jumlahDiambil: (_jumlahLiter ?? 0).toInt(),
                  createdAt: DateTime.now().toIso8601String(),
                  updatedAt: DateTime.now().toIso8601String(),
                  isDeleted: 0,
                  status: 'pending',
                );
                try {
                  await transaksiProvider.addTransaksi(transaksiBaru);
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Transaksi berhasil disimpan'),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal menyimpan transaksi: $e')),
                  );
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTransaksiTable(BuildContext context) {
    return Consumer<TransaksiProvider>(
      builder: (context, provider, _) {
        final transaksiListRaw = provider.transaksiList;
        final transaksiList = transaksiListRaw
            .map(
              (t) => t is TransaksiModel
                  ? t
                  : TransaksiModel(
                      transaksiId: t.transaksiId,
                      kuponId: t.kuponId,
                      nomorKupon: t.nomorKupon,
                      namaSatker: t.namaSatker,
                      jenisBbmId: t.jenisBbmId,
                      tanggalTransaksi: t.tanggalTransaksi,
                      jumlahLiter: t.jumlahLiter,
                      jumlahDiambil: t.jumlahDiambil,
                      createdAt: t.createdAt,
                      updatedAt:
                          t.updatedAt ?? DateTime.now().toIso8601String(),
                      isDeleted: t.isDeleted,
                      status: t.status,
                    ),
            )
            .toList();
        if (transaksiList.isEmpty) {
          return const Center(child: Text('Tidak ada data transaksi.'));
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Tanggal')),
              DataColumn(label: Text('Nomor Kupon')),
              DataColumn(label: Text('Jenis BBM')),
              DataColumn(label: Text('Jumlah (L)')),
              DataColumn(label: Text('Aksi')),
            ],
            rows: transaksiList
                .map(
                  (t) => DataRow(
                    cells: [
                      DataCell(Text(t.tanggalTransaksi)),
                      DataCell(Text(t.nomorKupon)),
                      DataCell(Text(t.jenisBbmId == 1 ? 'Pertamax' : 'Dex')),
                      DataCell(Text(t.jumlahDiambil.toString())),
                      DataCell(
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () =>
                                  _showEditTransaksiDialog(context, t),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Hapus Transaksi'),
                                    content: const Text(
                                      'Yakin ingin menghapus transaksi ini?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(false),
                                        child: const Text('Batal'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(true),
                                        child: const Text('Hapus'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  final transaksiProvider =
                                      Provider.of<TransaksiProvider>(
                                        context,
                                        listen: false,
                                      );
                                  await transaksiProvider.deleteTransaksi(
                                    t.transaksiId,
                                  );
                                }
                              },
                            ),
                          ],
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

  Future<void> _showEditTransaksiDialog(
    BuildContext context,
    TransaksiModel t,
  ) async {
    final transaksiProvider = Provider.of<TransaksiProvider>(
      context,
      listen: false,
    );
    final _formKey = GlobalKey<FormState>();
    final _tanggalController = TextEditingController(text: t.tanggalTransaksi);
    final _jumlahController = TextEditingController(
      text: t.jumlahDiambil.toString(),
    );
    int _jenisBBM = t.jenisBbmId;
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Edit Transaksi'),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _tanggalController,
                  decoration: const InputDecoration(labelText: 'Tanggal'),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Wajib diisi' : null,
                ),
                DropdownButtonFormField<int>(
                  value: _jenisBBM,
                  decoration: const InputDecoration(labelText: 'Jenis BBM'),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Pertamax')),
                    DropdownMenuItem(value: 2, child: Text('Pertamina Dex')),
                  ],
                  onChanged: (val) => _jenisBBM = val ?? t.jenisBbmId,
                  validator: (v) => v == null ? 'Wajib dipilih' : null,
                ),
                TextFormField(
                  controller: _jumlahController,
                  decoration: const InputDecoration(labelText: 'Jumlah Liter'),
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Wajib diisi' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_formKey.currentState?.validate() ?? false) {
                  final transaksiEdit = TransaksiModel(
                    transaksiId: t.transaksiId,
                    kuponId: t.kuponId,
                    nomorKupon: t.nomorKupon,
                    namaSatker: t.namaSatker,
                    jenisBbmId: _jenisBBM,
                    tanggalTransaksi: _tanggalController.text,
                    jumlahLiter:
                        double.tryParse(_jumlahController.text) ??
                        t.jumlahLiter,
                    createdAt: t.createdAt,
                    updatedAt: DateTime.now().toIso8601String(),
                    isDeleted: t.isDeleted,
                    jumlahDiambil:
                        (double.tryParse(_jumlahController.text) ??
                                t.jumlahLiter)
                            .toInt(),
                    status: t.status,
                  );
                  await transaksiProvider.updateTransaksi(transaksiEdit);
                  Navigator.of(ctx).pop();
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildKuponMinusTable(BuildContext context) {
    return Consumer<TransaksiProvider>(
      builder: (context, provider, _) {
        final minus = provider.kuponMinusList;
        if (minus.isEmpty) {
          return const Center(child: Text('Tidak ada kupon minus.'));
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Nomor Kupon')),
              DataColumn(label: Text('Kuota Sisa')),
              DataColumn(label: Text('Jenis BBM')),
              DataColumn(label: Text('Aksi')),
            ],
            rows: minus
                .map(
                  (m) => DataRow(
                    cells: [
                      DataCell(Text(m['nomor_kupon'].toString())),
                      DataCell(Text(m['kuota_sisa'].toString())),
                      DataCell(Text(m['jenis_bbm_id'].toString())),
                      DataCell(
                        IconButton(
                          icon: const Icon(Icons.download),
                          onPressed: () {
                            /* TODO: Export kupon minus */
                          },
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
}

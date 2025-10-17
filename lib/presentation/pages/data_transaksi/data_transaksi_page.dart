
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../providers/transaksi_provider.dart';
import 'show_detail_transaksi_dialog.dart';

class DataTransaksiPage extends StatefulWidget {
  const DataTransaksiPage({super.key});

  @override
  State<DataTransaksiPage> createState() => _DataTransaksiPageState();
}

class _DataTransaksiPageState extends State<DataTransaksiPage> {
  void _navigateToTransaksiForm({required int jenisKuponId, required int jenisBbmId}) {
    // TODO: Implement navigation to transaction form, passing jenisKuponId and jenisBbmId
    // Example: Navigator.push(...)
    print('Navigate to form: jenisKuponId=$jenisKuponId, jenisBbmId=$jenisBbmId');
  }
  int? _selectedBulan;
  int? _selectedTahun;

  final List<int> _bulanList = List.generate(12, (i) => i + 1);
  final List<int> _tahunList = [DateTime.now().year, DateTime.now().year + 1];

  // Map jenis BBM untuk tampilan
  final Map<int, String> _jenisBBMMap = {1: 'Pertamax', 2: 'Pertamina Dex'};

  // Map jenis kupon untuk tampilan
  final Map<int, String> _jenisKuponMap = {1: 'RANJEN', 2: 'DUKUNGAN'};

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = Provider.of<TransaksiProvider>(context, listen: false);
    provider.fetchTransaksiFiltered();
    provider.fetchKuponMinus();
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
                  child: Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          // Ranjen-Pertamax
                          _navigateToTransaksiForm(jenisKuponId: 1, jenisBbmId: 1);
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Ranjen - Pertamax'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          // Dukungan-Pertamax
                          _navigateToTransaksiForm(jenisKuponId: 2, jenisBbmId: 1);
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Dukungan - Pertamax'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          // Ranjen-Pertamina Dex
                          _navigateToTransaksiForm(jenisKuponId: 1, jenisBbmId: 2);
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Ranjen - Pertamina Dex'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          // Dukungan-Pertamina Dex
                          _navigateToTransaksiForm(jenisKuponId: 2, jenisBbmId: 2);
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Dukungan - Pertamina Dex'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
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
                          icon: const Icon(Icons.info_outline),
                          tooltip: 'Detail',
                          onPressed: () async {
                            showDialog(
                              context: context,
                              builder: (ctx) => ShowDetailTransaksiDialog(transaksi: t),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit),
                          tooltip: 'Edit',
                          onPressed: () async {
                            // Show confirmation before edit
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Konfirmasi Edit'),
                                content: const Text('Edit transaksi ini?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(false),
                                    child: const Text('Batal'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(true),
                                    child: const Text('Edit'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              // TODO: Implement edit logic and show success/error SnackBar
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Transaksi berhasil diedit!')),
                              );
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          tooltip: 'Delete',
                          onPressed: () async {
                            // Show confirmation before delete
                            final confirm = await showDialog<bool>(
                              context: context,
                              barrierDismissible: false,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Konfirmasi Hapus'),
                                content: const Text('Hapus transaksi ini?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(false),
                                    child: const Text('Batal'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(true),
                                    child: const Text('Hapus'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              // TODO: Implement delete logic and show success/error SnackBar
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Transaksi berhasil dihapus!')),
                              );
                            }
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

  // Export function for Transaksi table
  Future<void> _exportTransaksiToExcel() async {
    final provider = Provider.of<TransaksiProvider>(context, listen: false);
    final transaksi = provider.transaksiList;

    if (transaksi.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak ada data transaksi untuk diexport'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Create Excel workbook
      var excel = excel_lib.Excel.createExcel();
      var sheet = excel['Data Transaksi'];

      // Define cell styles
      var headerStyle = excel_lib.CellStyle(
        bold: true,
        horizontalAlign: excel_lib.HorizontalAlign.Center,
        verticalAlign: excel_lib.VerticalAlign.Center,
      );

      var dataStyle = excel_lib.CellStyle(
        horizontalAlign: excel_lib.HorizontalAlign.Left,
        verticalAlign: excel_lib.VerticalAlign.Center,
      );

      var numberStyle = excel_lib.CellStyle(
        horizontalAlign: excel_lib.HorizontalAlign.Right,
        verticalAlign: excel_lib.VerticalAlign.Center,
      );

      // Define headers
      var headers = [
        'Tanggal',
        'Nomor Kupon',
        'Satker',
        'Jenis BBM',
        'Jenis Kupon',
        'Jumlah (L)',
      ];

      // Write headers
      for (var i = 0; i < headers.length; i++) {
        sheet.cell(
            excel_lib.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
          )
          ..value = excel_lib.TextCellValue(headers[i])
          ..cellStyle = headerStyle;
      }

      // Write data rows
      var rowIndex = 1;
      for (final t in transaksi) {
        var row = [
          t.tanggalTransaksi,
          t.nomorKupon,
          t.namaSatker,
          _jenisBBMMap[t.jenisBbmId] ?? 'Unknown',
          'RANJEN', // Default jenis kupon
          t.jumlahLiter.toString(),
        ];

        for (var i = 0; i < row.length; i++) {
          var cell = sheet.cell(
            excel_lib.CellIndex.indexByColumnRow(
              columnIndex: i,
              rowIndex: rowIndex,
            ),
          );

          if (i == 5) {
            // Numeric column for jumlah liter
            cell
              ..value = excel_lib.DoubleCellValue(t.jumlahLiter)
              ..cellStyle = numberStyle;
          } else {
            cell
              ..value = excel_lib.TextCellValue(row[i])
              ..cellStyle = dataStyle;
          }
        }
        rowIndex++;
      }

      // Remove default Sheet1 if exists
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      // Save file
      final outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Simpan File Excel Transaksi',
        fileName:
            'data_transaksi_${DateTime.now().millisecondsSinceEpoch}.xlsx',
        allowedExtensions: ['xlsx'],
        type: FileType.custom,
      );

      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsBytes(excel.encode()!);

        if (context.mounted) {
          Navigator.pop(context); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Export transaksi berhasil: $outputFile'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (context.mounted) {
          Navigator.pop(context); // Close loading dialog
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal export transaksi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Export function for Kupon Minus table
  Future<void> _exportKuponMinusToExcel() async {
    final provider = Provider.of<TransaksiProvider>(context, listen: false);
    final kuponMinusList = provider.kuponMinusList;

    if (kuponMinusList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak ada data kupon minus untuk diexport'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Create Excel workbook
      var excel = excel_lib.Excel.createExcel();
      var sheet = excel['Kupon Minus'];

      // Define cell styles
      var headerStyle = excel_lib.CellStyle(
        bold: true,
        horizontalAlign: excel_lib.HorizontalAlign.Center,
        verticalAlign: excel_lib.VerticalAlign.Center,
      );

      var dataStyle = excel_lib.CellStyle(
        horizontalAlign: excel_lib.HorizontalAlign.Left,
        verticalAlign: excel_lib.VerticalAlign.Center,
      );

      var numberStyle = excel_lib.CellStyle(
        horizontalAlign: excel_lib.HorizontalAlign.Right,
        verticalAlign: excel_lib.VerticalAlign.Center,
      );

      // Define headers
      var headers = [
        'Nomor Kupon',
        'Jenis Kupon',
        'Jenis BBM',
        'Satker',
        'Kuota Satker',
        'Kuota Sisa',
        'Minus',
      ];

      // Write headers
      for (var i = 0; i < headers.length; i++) {
        sheet.cell(
            excel_lib.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
          )
          ..value = excel_lib.TextCellValue(headers[i])
          ..cellStyle = headerStyle;
      }

      // Write data rows
      var rowIndex = 1;
      for (final m in kuponMinusList) {
        var row = [
          m['nomor_kupon']?.toString() ?? '',
          _jenisKuponMap[m['jenis_kupon_id']] ?? 'Unknown',
          _jenisBBMMap[m['jenis_bbm_id']] ?? 'Unknown',
          m['nama_satker']?.toString() ?? '',
          m['kuota_satker']?.toString() ?? '0',
          m['kuota_sisa']?.toString() ?? '0',
          m['minus']?.toString() ?? '0',
        ];

        for (var i = 0; i < row.length; i++) {
          var cell = sheet.cell(
            excel_lib.CellIndex.indexByColumnRow(
              columnIndex: i,
              rowIndex: rowIndex,
            ),
          );

          if (i >= 4) {
            // Numeric columns (kuota_satker, kuota_sisa, minus)
            final numValue = double.tryParse(row[i]) ?? 0.0;
            cell
              ..value = excel_lib.DoubleCellValue(numValue)
              ..cellStyle = numberStyle;
          } else {
            cell
              ..value = excel_lib.TextCellValue(row[i])
              ..cellStyle = dataStyle;
          }
        }
        rowIndex++;
      }

      // Remove default Sheet1 if exists
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      // Save file
      final outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Simpan File Excel Kupon Minus',
        fileName: 'kupon_minus_${DateTime.now().millisecondsSinceEpoch}.xlsx',
        allowedExtensions: ['xlsx'],
        type: FileType.custom,
      );

      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsBytes(excel.encode()!);

        if (context.mounted) {
          Navigator.pop(context); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Export kupon minus berhasil: $outputFile'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (context.mounted) {
          Navigator.pop(context); // Close loading dialog
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal export kupon minus: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Build Kupon Minus Table widget
  Widget _buildKuponMinusTable(BuildContext context) {
    return Consumer<TransaksiProvider>(
      builder: (context, provider, _) {
        final kuponMinusList = provider.kuponMinusList;

        if (kuponMinusList.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text(
                'Tidak ada data kupon minus',
                style: TextStyle(fontSize: 18),
              ),
            ),
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Nomor Kupon')),
              DataColumn(label: Text('Jenis Kupon')),
              DataColumn(label: Text('Jenis BBM')),
              DataColumn(label: Text('Satker')),
              DataColumn(label: Text('Kuota Satker')),
              DataColumn(label: Text('Kuota Sisa')),
              DataColumn(label: Text('Minus')),
            ],
            rows: kuponMinusList.map((m) {
              return DataRow(
                cells: [
                  DataCell(Text(m['nomor_kupon']?.toString() ?? '')),
                  DataCell(
                    Text(_jenisKuponMap[m['jenis_kupon_id']] ?? 'Unknown'),
                  ),
                  DataCell(Text(_jenisBBMMap[m['jenis_bbm_id']] ?? 'Unknown')),
                  DataCell(Text(m['nama_satker']?.toString() ?? '')),
                  DataCell(Text(m['kuota_satker']?.toString() ?? '0')),
                  DataCell(Text(m['kuota_sisa']?.toString() ?? '0')),
                  DataCell(Text(m['minus']?.toString() ?? '0')),
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
      appBar: AppBar(title: const Text('Data Transaksi')),
      body: Column(
        children: [
          _buildFilterSection(),
          // Transaksi Table Section
          Expanded(
            flex: 2,
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
                          onPressed: _exportTransaksiToExcel,
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
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _buildTransaksiTable(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Kupon Minus Table Section
          Expanded(
            flex: 1,
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
                          'Data Kupon Minus',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _exportKuponMinusToExcel,
                          icon: const Icon(Icons.download),
                          label: const Text('Export'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _buildKuponMinusTable(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
// ...existing code...

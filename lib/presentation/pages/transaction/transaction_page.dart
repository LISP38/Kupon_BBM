import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
// import 'package:get_it/get_it.dart';
import '../../providers/transaksi_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../../data/models/transaksi_model.dart';
import '../../../domain/entities/kupon_entity.dart';
import '../../../domain/repositories/kendaraan_repository.dart';
import '../../../core/di/dependency_injection.dart';

class TransactionPage extends StatefulWidget {
  const TransactionPage({super.key});

  @override
  State<TransactionPage> createState() => _TransactionPageState();
}

class _TransactionPageState extends State<TransactionPage> {
  // Map jenis BBM untuk tampilan
  final Map<int, String> _jenisBBMMap = {1: 'Pertamax', 2: 'Pertamina Dex'};

  // Map jenis kupon untuk tampilan
  final Map<int, String> _jenisKuponMap = {1: 'RANJEN', 2: 'DUKUNGAN'};

  // Filter tanggal
  DateTime? _filterTanggalMulai;
  DateTime? _filterTanggalSelesai;
  int? _filterSatkerId;
  final List<Map<String, dynamic>> _satkerList = [
    {'satker_id': 0, 'nama_satker': 'Cadangan'},
    // TODO: Replace with actual satker list from provider/database if available
    {'satker_id': 1, 'nama_satker': 'KAPOLDA'},
    {'satker_id': 2, 'nama_satker': 'WAKAPOLDA'},
    {'satker_id': 3, 'nama_satker': 'PROPAM'},
    // ... add more as needed
  ];

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

  String _getExpiredDate(int bulanTerbit, int tahunTerbit) {
    // Kupon berlaku sampai akhir bulan ke-2 setelah terbit
    var expMonth = bulanTerbit + 2;
    var expYear = tahunTerbit;

    // Jika bulan > 12, sesuaikan bulan dan tahun
    if (expMonth > 12) {
      expMonth -= 12;
      expYear += 1;
    }

    // Dapatkan tanggal terakhir dari bulan tersebut
    final lastDay = DateTime(expYear, expMonth + 1, 0).day;
    return '$lastDay ${_getBulanName(expMonth)} $expYear';
  }

  Future<void> _exportKuponMinusToExcel(BuildContext context) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final transaksiProvider = Provider.of<TransaksiProvider>(
        context,
        listen: false,
      );

      final kuponMinusList = transaksiProvider.kuponMinusList;

      if (kuponMinusList.isEmpty) {
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tidak ada data kupon minus untuk diexport'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Create a new Excel workbook and worksheet
      var excel = Excel.createExcel();
      var sheet = excel['Kupon Minus'];

      // Define cell styles
      var headerStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        textWrapping: TextWrapping.WrapText,
      );

      var dataStyle = CellStyle(
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
        textWrapping: TextWrapping.WrapText,
      );

      var numberStyle = CellStyle(
        horizontalAlign: HorizontalAlign.Right,
        verticalAlign: VerticalAlign.Center,
      );

      // Adding header
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
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          ..value = TextCellValue(headers[i])
          ..cellStyle = headerStyle;
      }

      // Adding data rows
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

        // Write row data with appropriate styles
        for (var i = 0; i < row.length; i++) {
          var cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIndex),
          );

          if (i >= 4) {
            // Numeric columns
            final numValue = double.tryParse(row[i].toString()) ?? 0.0;
            cell
              ..value = DoubleCellValue(numValue)
              ..cellStyle = numberStyle;
          } else {
            cell
              ..value = TextCellValue(row[i].toString())
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
        dialogTitle: 'Save Excel file',
        fileName: 'kupon_minus_${DateTime.now().millisecondsSinceEpoch}.xlsx',
        allowedExtensions: ['xlsx'],
        type: FileType.custom,
      );

      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsBytes(excel.encode()!);

        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File kupon minus berhasil disimpan'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (context.mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportToExcel(BuildContext context) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final transaksiProvider = Provider.of<TransaksiProvider>(
        context,
        listen: false,
      );
      final dashboardProvider = Provider.of<DashboardProvider>(
        context,
        listen: false,
      );

      final transaksi = transaksiProvider.transaksiList;

      // Create a new Excel workbook and worksheet
      var excel = Excel.createExcel();
      var sheet = excel['Transaksi BBM'];

      // Define cell styles
      var headerStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        textWrapping: TextWrapping.WrapText,
      );

      var dataStyle = CellStyle(
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
        textWrapping: TextWrapping.WrapText,
      );

      var numberStyle = CellStyle(
        horizontalAlign: HorizontalAlign.Right,
        verticalAlign: VerticalAlign.Center,
      );

      // Adding header
      var headers = [
        'Tanggal',
        'No. Kupon',
        'No. Pol',
        'Jenis BBM',
        'Jenis Kupon',
        'Jatah Liter',
        'Sisa Liter',
      ];

      // Write headers
      for (var i = 0; i < headers.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          ..value = TextCellValue(headers[i])
          ..cellStyle = headerStyle;
      }

      // Adding data rows
      var rowIndex = 1;
      for (final t in transaksi) {
        // Find corresponding kupon
        final kupon = dashboardProvider.kuponList.firstWhere(
          (k) => k.kuponId == t.kuponId,
          orElse: () => dashboardProvider.kuponList.first,
        );

        // Get kendaraan data from repository
        final kendaraanRepo = getIt<KendaraanRepository>();
        final kendaraan = kupon.kendaraanId != null
            ? await kendaraanRepo.getKendaraanById(kupon.kendaraanId!)
            : null;

        // Format nopol dengan format standar nomor-kode
        final noPolWithKode = kendaraan != null
            ? '${kendaraan.noPolNomor}-${kendaraan.noPolKode}'
            : 'N/A';

        var row = [
          t.tanggalTransaksi,
          t.nomorKupon,
          noPolWithKode,
          _jenisBBMMap[t.jenisBbmId] ?? 'Unknown',
          _jenisKuponMap[kupon.jenisKuponId] ?? 'Unknown',
          t.jumlahLiter.toDouble(),
          kupon.kuotaSisa.toDouble(),
        ];

        // Write row data with appropriate styles
        for (var i = 0; i < row.length; i++) {
          var cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIndex),
          );

          if (i >= 5) {
            // Numeric columns (Jatah Liter & Sisa Liter)
            cell
              ..value = DoubleCellValue(row[i] as double)
              ..cellStyle = numberStyle;
          } else {
            cell
              ..value = TextCellValue(row[i].toString())
              ..cellStyle = dataStyle;
          }
        }
        rowIndex++;
      }

      // Save file
      final outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Excel file',
        fileName: 'transaksi_bbm.xlsx',
        allowedExtensions: ['xlsx'],
        type: FileType.custom,
      );

      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsBytes(excel.encode()!);

        if (context.mounted) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File berhasil disimpan'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Hide loading indicator
      if (context.mounted) {
        Navigator.pop(context);
      }
    }
  }

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

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange:
          _filterTanggalMulai != null && _filterTanggalSelesai != null
          ? DateTimeRange(
              start: _filterTanggalMulai!,
              end: _filterTanggalSelesai!,
            )
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _filterTanggalMulai = picked.start;
        _filterTanggalSelesai = picked.end;
      });
    }
  }

  void _clearDateFilter() {
    setState(() {
      _filterTanggalMulai = null;
      _filterTanggalSelesai = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Transaksi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export Excel',
            onPressed: () => _exportToExcel(context),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Riwayat Transaksi Terhapus',
            onPressed: () => _showDeletedTransaksiDialog(context),
          ),
        ],
      ),
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
                  child: DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Bulan',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: Provider.of<TransaksiProvider>(context).filterBulan,
                    items: [
                      for (int i = 1; i <= 12; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text(_getBulanName(i)),
                        ),
                    ],
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
                    initialValue: Provider.of<TransaksiProvider>(context).filterTahun,
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
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Satker',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: _filterSatkerId,
                    items: _satkerList
                        .map((s) => DropdownMenuItem<int>(
                              value: s['satker_id'] as int,
                              child: Text(s['nama_satker'] as String),
                            ))
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        _filterSatkerId = val;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Filter Tanggal
                OutlinedButton.icon(
                  onPressed: () => _selectDateRange(context),
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    _filterTanggalMulai != null && _filterTanggalSelesai != null
                        ? '${_filterTanggalMulai!.day}/${_filterTanggalMulai!.month}/${_filterTanggalMulai!.year} - ${_filterTanggalSelesai!.day}/${_filterTanggalSelesai!.month}/${_filterTanggalSelesai!.year}'
                        : 'Pilih Range Tanggal',
                  ),
                ),
                if (_filterTanggalMulai != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: 'Hapus Filter Tanggal',
                    onPressed: _clearDateFilter,
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
                  onPressed: () => _showTambahTransaksiDialog(context, jenisBbm: 1, jenisKuponId: 1),
                  icon: const Icon(Icons.add),
                  label: const Text('Ranjen - Pertamax'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showTambahTransaksiDialog(context, jenisBbm: 1, jenisKuponId: 2),
                  icon: const Icon(Icons.add),
                  label: const Text('Dukungan - Pertamax'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showTambahTransaksiDialog(context, jenisBbm: 2, jenisKuponId: 1),
                  icon: const Icon(Icons.add),
                  label: const Text('Ranjen - Pertamina Dex'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showTambahTransaksiDialog(context, jenisBbm: 2, jenisKuponId: 2),
                  icon: const Icon(Icons.add),
                  label: const Text('Dukungan - Pertamina Dex'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildTransaksiTable(context)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Kupon Minus',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: () => _exportKuponMinusToExcel(context),
                  icon: const Icon(Icons.download),
                  label: const Text('Export Kupon Minus'),
                ),
              ],
            ),
            Expanded(child: _buildKuponMinusTable(context)),
          ],
        ),
      ),
    );
  }

  void _exportTransaksi() async {
    final provider = Provider.of<TransaksiProvider>(context, listen: false);
    final dashboardProvider = Provider.of<DashboardProvider>(
      context,
      listen: false,
    );
    final transaksi = provider.transaksiList;

    if (transaksi.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak ada data transaksi untuk diexport.'),
        ),
      );
      return;
    }

    if (dashboardProvider.kuponList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data kupon tidak tersedia. Mohon refresh halaman.'),
        ),
      );
      return;
    }

    final excel = Excel.createExcel();
    final sheet = excel['Transaksi'];

    // Styling untuk header
    var headerStyle = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
    );

    // Menambahkan header dengan style
    var headers = [
      'Tanggal',
      'Nomor Kupon',
      'No Pol',
      'Jenis BBM',
      'Jenis Kupon',
      'Jumlah Ambil',
      'Jumlah Sisa',
    ];

    sheet.appendRow(headers.map((header) => TextCellValue(header)).toList());

    // Applying style to header row
    for (var i = 0; i < headers.length; i++) {
      var cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
      );
      cell.cellStyle = headerStyle;
    }

    // Auto size columns
    for (var i = 0; i < headers.length; i++) {
      sheet.setColumnAutoFit(i);
    }

    // Data style
    var dataStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );

    // Adding data rows
    for (final t in transaksi) {
      // Find corresponding kupon
      final matchingKupons = dashboardProvider.kuponList.where(
        (k) => k.kuponId == t.kuponId,
      );
      if (matchingKupons.isEmpty) {
        // Skip this transaction if no matching kupon found
        continue;
      }
      final kupon = matchingKupons.first;

      // Get kendaraan data from repository
      final kendaraanRepo = getIt<KendaraanRepository>();
      final kendaraan = kupon.kendaraanId != null
          ? await kendaraanRepo.getKendaraanById(kupon.kendaraanId!)
          : null;

      // Format nopol with VIII pattern
      final noPolWithKode = kendaraan != null
          ? '${kendaraan.noPolNomor}-VIII'
          : 'N/A';

      var row = [
        TextCellValue(t.tanggalTransaksi),
        TextCellValue(t.nomorKupon),
        TextCellValue(noPolWithKode),
        TextCellValue(_jenisBBMMap[t.jenisBbmId] ?? 'Unknown'),
        TextCellValue(_jenisKuponMap[kupon.jenisKuponId] ?? 'Unknown'),
        DoubleCellValue(t.jumlahLiter),
        DoubleCellValue(kupon.kuotaSisa),
      ];

      sheet.appendRow(row);

      // Apply style to data cells
      for (var i = 0; i < row.length; i++) {
        var cell = sheet.cell(
          CellIndex.indexByColumnRow(
            columnIndex: i,
            rowIndex: sheet.maxRows - 1,
          ),
        );
        cell.cellStyle = dataStyle;
      }
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
    required int jenisKuponId,
  }) async {
    final dashboardProvider = Provider.of<DashboardProvider>(
      context,
      listen: false,
    );
    final transaksiProvider = Provider.of<TransaksiProvider>(
      context,
      listen: false,
    );
    // Filter kuponList sesuai jenisBbm dan jenisKuponId
    final List<KuponEntity> kuponList = dashboardProvider.kuponList
        .where((k) => k.jenisBbmId == jenisBbm && k.jenisKuponId == jenisKuponId)
        .toList();
    final Map<int, String> jenisKuponMap = {1: 'RANJEN', 2: 'DUKUNGAN'};
    final List<String> kuponOptions = kuponList
        .map(
          (k) =>
              '${k.nomorKupon}/${k.bulanTerbit}/${k.tahunTerbit}/${k.namaSatker}/${jenisKuponMap[k.jenisKuponId] ?? k.jenisKuponId} (${k.kuotaSisa.toStringAsFixed(0)} L)',
        )
        .toList();
    final formKey = GlobalKey<FormState>();
    final tanggalController = TextEditingController();
    String? nomorKupon;
    double? jumlahLiter;
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Tambah Transaksi'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: tanggalController,
                  decoration: const InputDecoration(
                    labelText: 'Tanggal',
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Pilih tanggal transaksi'
                      : null,
                  readOnly: true,
                  onTap: () async {
                    final DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (pickedDate != null) {
                      tanggalController.text = DateFormat(
                        'yyyy-MM-dd',
                      ).format(pickedDate);
                    }
                  },
                ),
                Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return kuponOptions;
                    }
                    final filtered = kuponOptions.where((option) {
                      final nomorKupon = option.split('/')[0];
                      return nomorKupon.startsWith(textEditingValue.text);
                    });
                    return filtered;
                  },
                  onSelected: (value) {
                    nomorKupon = value;
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
                    jumlahLiter = double.tryParse(value);
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
                if (!formKey.currentState!.validate()) return;
                KuponEntity? kupon;
                for (final k in kuponList) {
                  final jenisKuponNama =
                      jenisKuponMap[k.jenisKuponId] ?? k.jenisKuponId;
                  final formatLengkap =
                      '${k.nomorKupon}/${k.bulanTerbit}/${k.tahunTerbit}/${k.namaSatker}/$jenisKuponNama (${k.kuotaSisa.toStringAsFixed(0)} L)';
                  if (formatLengkap == nomorKupon) {
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
                if (kupon.kuotaSisa < (jumlahLiter ?? 0)) {
                  final lanjut = await showDialog<bool>(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text('Konfirmasi'),
                        content: Text(
                          'Jumlah liter melebihi kuota sisa (${kupon?.kuotaSisa} L tersisa). Apakah tetap ingin melanjutkan?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Batal'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Lanjutkan'),
                          ),
                        ],
                      );
                    },
                  );

                  if (lanjut != true) return;
                }

                final transaksiBaru = TransaksiModel(
                  transaksiId: 0,
                  kuponId: kupon.kuponId,
                  nomorKupon: kupon.nomorKupon,
                  namaSatker: kupon.namaSatker,
                  jenisBbmId: jenisBbm,
                  tanggalTransaksi: tanggalController.text,
                  jumlahLiter: jumlahLiter ?? 0,
                  createdAt: DateTime.now().toIso8601String(),
                  updatedAt: DateTime.now().toIso8601String(),
                  isDeleted: 0,
                  status: 'pending',
                );
                try {
                  await transaksiProvider.addTransaksi(transaksiBaru);
                  // Refresh dashboard to update coupon quotas
                  await dashboardProvider.fetchKupons();
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
                      createdAt: t.createdAt,
                      updatedAt:
                          t.updatedAt ?? DateTime.now().toIso8601String(),
                      isDeleted: t.isDeleted,
                      status: t.status,
                    ),
            )
            .toList();

        // Apply date filter if set
        List<TransaksiModel> filteredList = transaksiList;
        if (_filterTanggalMulai != null && _filterTanggalSelesai != null) {
          filteredList = transaksiList.where((t) {
            try {
              final transaksiDate = DateTime.parse(t.tanggalTransaksi);
              return transaksiDate.isAfter(
                    _filterTanggalMulai!.subtract(const Duration(days: 1)),
                  ) &&
                  transaksiDate.isBefore(
                    _filterTanggalSelesai!.add(const Duration(days: 1)),
                  );
            } catch (e) {
              return true; // Include if date parsing fails
            }
          }).toList();
        }

        if (filteredList.isEmpty) {
          return const Center(child: Text('Tidak ada data transaksi.'));
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
            rows: filteredList
                .map(
                  (t) => DataRow(
                    cells: [
                      DataCell(Text(t.tanggalTransaksi)),
                      DataCell(Text(t.nomorKupon)),
                      DataCell(Text(t.namaSatker)),
                      DataCell(Text(_jenisBBMMap[t.jenisBbmId] ?? 'Unknown')),
                      DataCell(
                        Text('RANJEN'),
                      ), // We need to update this with actual jenis kupon
                      DataCell(Text(t.jumlahLiter.toString())),
                      DataCell(
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.info_outline),
                              onPressed: () async {
                                final dashboardProvider =
                                    Provider.of<DashboardProvider>(
                                      context,
                                      listen: false,
                                    );
                                final kuponList = dashboardProvider.kupons
                                    .where((k) => k.kuponId == t.kuponId)
                                    .toList();
                                if (kuponList.isNotEmpty) {
                                  final kupon = kuponList.first;
                                  await showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Detail Kupon'),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('Nomor: ${kupon.nomorKupon}'),
                                          Text('Satker: ${kupon.namaSatker}'),
                                          Text(
                                            'Jenis: ${_jenisKuponMap[kupon.jenisKuponId] ?? "Unknown"}',
                                          ),
                                          Text(
                                            'BBM: ${_jenisBBMMap[kupon.jenisBbmId] ?? "Unknown"}',
                                          ),
                                          Text(
                                            'Kuota Awal: ${kupon.kuotaAwal} L',
                                          ),
                                          Text(
                                            'Kuota Sisa: ${kupon.kuotaSisa} L',
                                          ),
                                          Text('Status: ${kupon.status}'),
                                          Text(
                                            'Periode: ${_getBulanName(kupon.bulanTerbit)} ${kupon.tahunTerbit}',
                                          ),
                                          Text(
                                            'Berlaku s/d: ${_getExpiredDate(kupon.bulanTerbit, kupon.tahunTerbit)}',
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text('Tutup'),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              },
                            ),
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
                                  final dashboardProvider =
                                      Provider.of<DashboardProvider>(
                                        context,
                                        listen: false,
                                      );
                                  await dashboardProvider.fetchKupons();
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
    final formKey = GlobalKey<FormState>();
    final tanggalController = TextEditingController(text: t.tanggalTransaksi);
    final jumlahController = TextEditingController(
      text: t.jumlahLiter.toString(),
    );
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Edit Transaksi'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: tanggalController,
                  decoration: const InputDecoration(
                    labelText: 'Tanggal',
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Wajib diisi' : null,
                  readOnly: true,
                  onTap: () async {
                    DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate:
                          DateTime.tryParse(tanggalController.text) ??
                          DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (pickedDate != null) {
                      tanggalController.text = DateFormat(
                        'yyyy-MM-dd',
                      ).format(pickedDate);
                    }
                  },
                ),
                TextFormField(
                  controller: jumlahController,
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
                if (formKey.currentState?.validate() ?? false) {
                  final dashboardProvider = Provider.of<DashboardProvider>(
                    context,
                    listen: false,
                  );
                  final transaksiEdit = TransaksiModel(
                    transaksiId: t.transaksiId,
                    kuponId: t.kuponId,
                    nomorKupon: t.nomorKupon,
                    namaSatker: t.namaSatker,
                    jenisBbmId: t.jenisBbmId, // Keep original BBM type
                    tanggalTransaksi: tanggalController.text,
                    jumlahLiter:
                        double.tryParse(jumlahController.text) ??
                        t.jumlahLiter,
                    createdAt: t.createdAt,
                    updatedAt: DateTime.now().toIso8601String(),
                    isDeleted: t.isDeleted,
                    status: t.status,
                  );
                  await transaksiProvider.updateTransaksi(transaksiEdit);
                  await dashboardProvider.fetchKupons();
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

  Future<void> _showDeletedTransaksiDialog(BuildContext context) async {
    final transaksiProvider = Provider.of<TransaksiProvider>(
      context,
      listen: false,
    );

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Ambil data transaksi yang terhapus
      await transaksiProvider.fetchDeletedTransaksi();

      if (context.mounted) {
        Navigator.pop(context); // Close loading
      }

      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Riwayat Transaksi Terhapus'),
            content: SizedBox(
              width: double.maxFinite,
              child: Consumer<TransaksiProvider>(
                builder: (context, provider, _) {
                  final deletedTransaksi = provider.deletedTransaksiList;
                  if (deletedTransaksi.isEmpty) {
                    return const Center(
                      child: Text('Tidak ada transaksi yang terhapus.'),
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
                        DataColumn(label: Text('Jumlah (L)')),
                        DataColumn(label: Text('Aksi')),
                      ],
                      rows: deletedTransaksi.map((t) {
                        // Safe parsing for jenisBbmId
                        int jenisBbmId = 0;
                        jenisBbmId = t.jenisBbmId;

                        // Safe parsing for jumlahLiter
                        double jumlahLiter = 0.0;
                        jumlahLiter = t.jumlahLiter;

                        return DataRow(
                          cells: [
                            DataCell(Text(t.tanggalTransaksi)),
                            DataCell(Text(t.nomorKupon)),
                            DataCell(Text(t.namaSatker)),
                            DataCell(
                              Text(_jenisBBMMap[jenisBbmId] ?? 'Unknown'),
                            ),
                            DataCell(Text(jumlahLiter.toString())),
                            DataCell(
                              IconButton(
                                icon: const Icon(Icons.restore),
                                tooltip: 'Kembalikan transaksi',
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Kembalikan Transaksi'),
                                      content: const Text(
                                        'Yakin ingin mengembalikan transaksi ini?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text('Batal'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text('Kembalikan'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    try {
                                      await transaksiProvider.restoreTransaksi(
                                        t.transaksiId,
                                      );
                                      // Refresh dashboard
                                      await Provider.of<DashboardProvider>(
                                        context,
                                        listen: false,
                                      ).fetchKupons();
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Transaksi berhasil dikembalikan',
                                            ),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Gagal mengembalikan transaksi: $e',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  }
                                },
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Tutup'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error mengambil data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
              DataColumn(label: Text('Jenis Kupon')),
              DataColumn(label: Text('Jenis BBM')),
              DataColumn(label: Text('Satker')),
              DataColumn(label: Text('Kuota Satker')),
              DataColumn(label: Text('Kuota Sisa')),
              DataColumn(label: Text('Minus')),
            ],
            rows: minus.map((m) {
              // Safe parsing untuk jenis_kupon_id
              int jenisKuponId = 0;
              if (m['jenis_kupon_id'] is int) {
                jenisKuponId = m['jenis_kupon_id'];
              } else if (m['jenis_kupon_id'] is double) {
                jenisKuponId = (m['jenis_kupon_id'] as double).toInt();
              } else if (m['jenis_kupon_id'] is String) {
                jenisKuponId =
                    int.tryParse(m['jenis_kupon_id'].toString()) ?? 0;
              }

              // Safe parsing untuk jenis_bbm_id
              int jenisBbmId = 0;
              if (m['jenis_bbm_id'] is int) {
                jenisBbmId = m['jenis_bbm_id'];
              } else if (m['jenis_bbm_id'] is double) {
                jenisBbmId = (m['jenis_bbm_id'] as double).toInt();
              } else if (m['jenis_bbm_id'] is String) {
                jenisBbmId = int.tryParse(m['jenis_bbm_id'].toString()) ?? 0;
              }

              return DataRow(
                cells: [
                  DataCell(Text(m['nomor_kupon']?.toString() ?? '')),
                  DataCell(Text(_jenisKuponMap[jenisKuponId] ?? 'Unknown')),
                  DataCell(Text(_jenisBBMMap[jenisBbmId] ?? 'Unknown')),
                  DataCell(Text(m['nama_satker']?.toString() ?? '')),
                  DataCell(Text('${m['kuota_satker'] ?? 0} L')),
                  DataCell(Text('${m['kuota_sisa'] ?? 0} L')),
                  DataCell(Text('${m['minus'] ?? 0} L')),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

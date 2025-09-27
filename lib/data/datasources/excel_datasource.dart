import 'dart:io';
import 'package:excel/excel.dart';
import 'package:kupon_bbm_app/data/models/kupon_model.dart';
import 'package:kupon_bbm_app/data/models/kendaraan_model.dart';
import 'package:kupon_bbm_app/data/validators/kupon_validator.dart';

class ExcelParseResult {
  final List<KuponModel> kupons;
  final List<KendaraanModel> newKendaraans;
  final List<String> validationMessages;

  ExcelParseResult({
    required this.kupons,
    required this.newKendaraans,
    required this.validationMessages,
  });
}

class ExcelDatasource {
  final KuponValidator _kuponValidator;
  static const String DEFAULT_KODE_NOPOL = 'VIII';

  ExcelDatasource(this._kuponValidator);

  // Helper untuk konversi angka romawi ke integer
  int? _parseRomanNumeral(String roman) {
    final Map<String, int> romanValues = {
      'I': 1,
      'II': 2,
      'III': 3,
      'IV': 4,
      'V': 5,
      'VI': 6,
      'VII': 7,
      'VIII': 8,
      'IX': 9,
      'X': 10,
      'XI': 11,
      'XII': 12,
    };

    return romanValues[roman.trim().toUpperCase()];
  }

Future<ExcelParseResult> parseExcelFile(
  String filePath,
  List<KuponModel> existingKupons, {
  bool allowReplace = false,
}) async {
    final bytes = File(filePath).readAsBytesSync();
    final excel = Excel.decodeBytes(bytes);

    final kupons = <KuponModel>[];
    final newKendaraans = <KendaraanModel>[];
    final validationMessages = <String>[];
    final Map<String, int> kendaraanBBMCount =
        {}; // Track jenis BBM per kendaraan
    final Map<String, Map<int, int>> kendaraanKuponCount =
        {}; // Track kupon per kendaraan per bulan

    // Hanya ambil sheet pertama
    if (excel.tables.isEmpty) {
      throw Exception('File Excel tidak memiliki sheet');
    }
    final sheet = excel.tables[excel.tables.keys.first]!;

    // Langsung proses semua baris sebagai data (tanpa header)
    for (var row in sheet.rows) {
      try {
        // Parse data dari row
        final data = _parseRow(row);
        if (data != null) {
          final (kupon, kendaraan) = data;

            if (kendaraan != null) {
              // Validasi business rules
              final validationResult = await _kuponValidator.validateKupon(
                existingKupons,
                kupon,
                '${kendaraan.noPolKode} ${kendaraan.noPolNomor}',
                allowReplace: allowReplace,
              );

              if (!validationResult.isValid) {
                validationMessages.addAll(
                  validationResult.messages.map(
                    (msg) => 'Baris ${sheet.rows.indexOf(row) + 1}: $msg',
                  ),
                );
                if (!allowReplace) {
                  continue; // Skip row ini jika tidak valid dan bukan replace mode
                }
              }

              kupons.add(kupon);
              newKendaraans.add(kendaraan);
            }
        }
      } catch (e) {
        validationMessages.add(
          'Error pada baris ${sheet.rows.indexOf(row) + 1}: ${e.toString()}',
        );
      }
    }

    return ExcelParseResult(
      kupons: kupons,
      newKendaraans: newKendaraans,
      validationMessages: validationMessages,
    );
  }

  // Helper untuk normalisasi cell
  String _getCellString(List<Data?> row, int index) {
    if (index >= row.length) return '';
    final raw = row[index]?.value;
    if (raw == null) return '';
    final str = raw.toString().trim();
    return str;
  }

  (KuponModel, KendaraanModel?)? _parseRow(List<Data?> row) {
    if (row.isEmpty || row.length < 10) return null;

    // Skip empty rows or headers
    final cell0 = _getCellString(row, 0);
    final cell1 = _getCellString(row, 1);

    // Skip if both first and second columns are empty
    if (cell0.isEmpty && cell1.isEmpty) {
      print('Debug - Skipping empty row');
      return null;
    }

    // Skip if it looks like a header
    if (cell0.toLowerCase().contains('jenis') ||
        cell1.toLowerCase().contains('no')) {
      print('Debug - Skipping header row');
      return null;
    }

    final jenisKupon = cell0;

    // No Kupon - DIPERBAIKI untuk handle berbagai format
    final noKuponStr = _getCellString(row, 1);
    print('Debug - No Kupon raw: "$noKuponStr"'); // Debug line

    if (noKuponStr.isEmpty) {
      throw Exception('No Kupon tidak boleh kosong');
    }

    // Coba extract angka dari string
    final match = RegExp(r'\d+').firstMatch(noKuponStr);
    if (match == null) {
      throw Exception(
        'No Kupon harus mengandung angka. Ditemukan: "$noKuponStr"',
      );
    }
    final noKupon = match.group(0)!;

    // Bulan (romawi) - DIPERBAIKI
    final bulanStr = _getCellString(row, 2).toUpperCase();
    print('Debug - Bulan raw: "$bulanStr"'); // Debug line

    final bulanClean = RegExp(r'[IVXLCDM]+').stringMatch(bulanStr) ?? '';
    final bulan = _parseRomanNumeral(bulanClean);
    if (bulan == null) {
      throw Exception(
        'Format bulan tidak valid. Gunakan angka romawi (I-XII). Ditemukan: "$bulanStr"',
      );
    }

    final tahunStr = _getCellString(row, 3);
    final tahun = int.tryParse(tahunStr) ?? 0;
    if (tahun == 0) {
      throw Exception('Tahun tidak valid. Ditemukan: "$tahunStr"');
    }

    final jenisRanmor = _getCellString(row, 4);
    final satker = _getCellString(row, 5);

    // No Pol - DIPERBAIKI dengan debug info
    final noPolStr = _getCellString(row, 6);
    print('Debug - No Pol raw: "$noPolStr"'); // Debug line

    if (noPolStr.isEmpty) {
      throw Exception('No Pol tidak boleh kosong');
    }

    // Extract angka dari No Pol
    final noPolMatch = RegExp(r'\d+').firstMatch(noPolStr);
    if (noPolMatch == null) {
      throw Exception('No Pol harus mengandung angka. Ditemukan: "$noPolStr"');
    }
    final noPol = noPolMatch.group(0)!;

    final kodeNopol = _getCellString(row, 7); // Ini kolom H (Kode)
    final jenisBBM = _getCellString(row, 8);
    final kuantumStr = _getCellString(row, 9);
    final kuantum = double.tryParse(kuantumStr) ?? 0.0;

    print('Debug - Jenis BBM: "$jenisBBM"'); // Debug line
    print('Debug - Kuantum: "$kuantumStr" -> $kuantum'); // Debug line

    // Validasi jenis BBM dengan lebih fleksibel
    if (!jenisBBM.toLowerCase().contains('pertamax') &&
        !jenisBBM.toLowerCase().contains('dex')) {
      throw Exception(
        'Jenis BBM harus Pertamax atau Pertamina Dex. Ditemukan: "$jenisBBM"',
      );
    }

    // Validasi data lengkap
    if (noKupon.isEmpty ||
        bulan < 1 ||
        bulan > 12 ||
        tahun < 2000 ||
        jenisRanmor.isEmpty ||
        satker.isEmpty ||
        jenisBBM.isEmpty ||
        kuantum <= 0) {
      throw Exception('Data tidak lengkap atau tidak valid');
    }

    final tanggalMulai = DateTime(tahun, bulan, 1);
    final tanggalSampai = DateTime(
      tahun,
      bulan + 1,
      0,
    ); // Akhir bulan yang sama

    // Gunakan kode yang ada di Excel atau default
    final finalKodeNopol = kodeNopol.isNotEmpty
        ? kodeNopol
        : DEFAULT_KODE_NOPOL;

    print('Debug - Creating KendaraanModel with noPolNomor: "$noPol"');

    final kendaraan = KendaraanModel(
      kendaraanId: 0,
      satkerId: 1, // Menggunakan satker_id default = 1
      jenisRanmor: jenisRanmor,
      noPolKode: finalKodeNopol,
      noPolNomor: noPolStr, // Gunakan string asli, bukan hasil extract
      statusAktif: 1,
      createdAt: DateTime.now().toIso8601String(),
    );

    // Tentukan jenis BBM ID
    int jenisBbmId = 1; // Default Pertamax
    if (jenisBBM.toLowerCase().contains('dex')) {
      jenisBbmId = 2;
    }

    final kupon = KuponModel(
      kuponId: 0,
      nomorKupon: noKupon,
      kendaraanId: 0,
      jenisBbmId: jenisBbmId,
      jenisKuponId: jenisKupon == 'Ranjen' ? 1 : 2,
      bulanTerbit: bulan,
      tahunTerbit: tahun,
      tanggalMulai: tanggalMulai.toIso8601String(),
      tanggalSampai: tanggalSampai.toIso8601String(),
      kuotaAwal: kuantum,
      kuotaSisa: kuantum,
      namaSatker: satker,
      status: 'Aktif',
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
      isDeleted: 0,
    );

    return (kupon, kendaraan);
  }
}

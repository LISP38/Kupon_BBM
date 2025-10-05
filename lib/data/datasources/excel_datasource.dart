import 'dart:io';
import 'package:excel/excel.dart';
import 'package:kupon_bbm_app/data/datasources/database_datasource.dart';
import 'package:kupon_bbm_app/data/models/kupon_model.dart';
import 'package:kupon_bbm_app/data/models/kendaraan_model.dart';
import 'package:kupon_bbm_app/data/validators/kupon_validator.dart';

class ExcelParseResult {
  final List<KuponModel> kupons;
  final List<KendaraanModel> newKendaraans;
  final List<KuponModel> duplicateKupons;
  final List<KendaraanModel> duplicateKendaraans;
  final List<String> validationMessages;

  ExcelParseResult({
    required this.kupons,
    required this.newKendaraans,
    this.duplicateKupons = const [],
    this.duplicateKendaraans = const [],
    required this.validationMessages,
  });
}

class ExcelDatasource {
  final KuponValidator _kuponValidator;
  final DatabaseDatasource _databaseDatasource;
  static const String DEFAULT_KODE_NOPOL = 'VIII';

  ExcelDatasource(this._kuponValidator, this._databaseDatasource);

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
    List<KuponModel> existingKupons,
  ) async {
    final bytes = File(filePath).readAsBytesSync();
    final excel = Excel.decodeBytes(bytes);

    final kupons = <KuponModel>[];
    final newKendaraans = <KendaraanModel>[];
    final duplicateKupons = <KuponModel>[];
    final duplicateKendaraans = <KendaraanModel>[];
    final validationMessages = <String>[];

    // Hanya ambil sheet pertama
    if (excel.tables.isEmpty) {
      throw Exception('File Excel tidak memiliki sheet');
    }
    final sheet = excel.tables[excel.tables.keys.first]!;

    // Langsung proses semua baris sebagai data (tanpa header)
    for (int i = 0; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      final rowNumber = i + 1;
      try {
        // Parse data dari row
        final data = await _parseRow(row);
        if (data != null) {
          final (kupon, kendaraan) = data;

          // Validasi business rules - berbeda untuk RANJEN dan DUKUNGAN
          final noPol = kendaraan != null
              ? '${kendaraan.noPolNomor}-${kendaraan.noPolKode}'
              : 'N/A (DUKUNGAN)';

          final validationResult = _kuponValidator.validateKupon(
            existingKupons,
            kupon,
            noPol,
            currentBatchKupons:
                kupons, // Kupon yang sudah diproses dalam batch ini
          );

          print(
            'DEBUG - Validating kupon ${kupon.nomorKupon}: ${validationResult.isValid}',
          );
          if (!validationResult.isValid) {
            print('DEBUG - Validation messages: ${validationResult.messages}');
          }

          if (!validationResult.isValid) {
            // Cek apakah ini duplikat atau error lain
            final isDuplicate = validationResult.messages.any(
              (msg) =>
                  msg.toLowerCase().contains('sudah ada') ||
                  msg.toLowerCase().contains('duplikat') ||
                  (msg.toLowerCase().contains('kupon') &&
                      msg.toLowerCase().contains('sistem')),
            );

            print(
              'DEBUG - Is duplicate: $isDuplicate for kupon ${kupon.nomorKupon}',
            );

            if (isDuplicate) {
              // Ini duplikat - masukkan ke list duplikat untuk preview
              duplicateKupons.add(kupon);
              if (kendaraan != null) {
                duplicateKendaraans.add(kendaraan);
              }
              validationMessages.add(
                'Baris $rowNumber: DUPLIKAT - ${validationResult.messages.join(", ")}',
              );
            } else {
              // Error lain - masukkan ke validation messages saja
              validationMessages.addAll(
                validationResult.messages.map(
                  (msg) => 'Baris $rowNumber: $msg',
                ),
              );
            }
          } else {
            // Validasi berhasil - ini kupon baru
            kupons.add(kupon);
            if (kendaraan != null) {
              newKendaraans.add(kendaraan);
            }
          }
        }
      } catch (e) {
        validationMessages.add('Error pada baris $rowNumber: ${e.toString()}');
      }
    }

    return ExcelParseResult(
      kupons: kupons,
      newKendaraans: newKendaraans,
      duplicateKupons: duplicateKupons,
      duplicateKendaraans: duplicateKendaraans,
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

  Future<(KuponModel, KendaraanModel?)?> _parseRow(List<Data?> row) async {
    if (row.isEmpty || row.length < 10) return null;

    // Skip empty rows or headers
    final cell0 = _getCellString(row, 0);
    final cell1 = _getCellString(row, 1);

    // Skip if both first and second columns are empty
    if (cell0.isEmpty && cell1.isEmpty) {
      print('Debug - Skipping empty row');
      return null;
    }

    // Skip if it looks like a header - lebih comprehensive check
    if (cell0.toLowerCase().contains('jenis') ||
        cell1.toLowerCase().contains('no') ||
        cell0.toLowerCase().contains('kupon') ||
        cell1.toLowerCase().contains('kupon')) {
      print('Debug - Skipping header row: "$cell0", "$cell1"');
      return null;
    }

    // Skip jika baris tidak memiliki data minimal (jenisKupon dan noKupon)
    if (cell0.trim().isEmpty || cell1.trim().isEmpty) {
      print(
        'Debug - Skipping incomplete row: jenisKupon="$cell0", noKupon="$cell1"',
      );
      return null;
    }

    final jenisKupon = cell0;
    print('Debug - Jenis Kupon: "$jenisKupon"'); // Debug line

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

    // No Pol - Handle untuk kupon DUKUNGAN yang bisa kosong
    final noPolStr = _getCellString(row, 6);
    print('Debug - No Pol raw: "$noPolStr"'); // Debug line

    // Untuk kupon DUKUNGAN, No Pol bisa kosong
    final isDukungan = jenisKupon.toLowerCase().contains('dukungan');
    String? noPol;

    if (noPolStr.isEmpty) {
      if (!isDukungan) {
        throw Exception('No Pol tidak boleh kosong untuk kupon RANJEN');
      }
      // Untuk DUKUNGAN, noPol bisa null
      noPol = null;
    } else {
      // Extract angka dari No Pol
      final noPolMatch = RegExp(r'\d+').firstMatch(noPolStr);
      if (noPolMatch == null) {
        throw Exception(
          'No Pol harus mengandung angka. Ditemukan: "$noPolStr"',
        );
      }
      noPol = noPolMatch.group(0)!;
    }

    final kodeNopol = _getCellString(row, 7); // Ini kolom H (Kode)
    final jenisBBM = _getCellString(row, 8);
    final kuantumStr = _getCellString(row, 9);
    final kuantum = double.tryParse(kuantumStr) ?? 0.0;

    print('Debug - Jenis BBM: "$jenisBBM"'); // Debug line
    print('Debug - Kuantum: "$kuantumStr" -> $kuantum'); // Debug line

    // Validasi jenis BBM dengan lebih fleksibel
    final jenisBBMLower = jenisBBM.toLowerCase();
    if (!jenisBBMLower.contains('pertamax') &&
        !jenisBBMLower.contains('dex') &&
        !jenisBBMLower.contains('solar')) {
      throw Exception(
        'Jenis BBM harus mengandung kata Pertamax, Dex, atau Solar. Ditemukan: "$jenisBBM"',
      );
    }

    // Validasi data lengkap - berbeda untuk RANJEN dan DUKUNGAN
    print('Debug - Validasi Detail:');
    print('  noKupon: "$noKupon" (kosong: ${noKupon.isEmpty})');
    print('  bulan: $bulan (valid: ${bulan >= 1 && bulan <= 12})');
    print('  tahun: $tahun (valid: ${tahun >= 2000})');
    print('  satker: "$satker" (kosong: ${satker.isEmpty})');
    print('  jenisBBM: "$jenisBBM" (kosong: ${jenisBBM.isEmpty})');
    print('  kuantum: $kuantum (valid: ${kuantum > 0})');

    final basicValidation =
        noKupon.isEmpty ||
        bulan < 1 ||
        bulan > 12 ||
        tahun < 2000 ||
        satker.isEmpty ||
        jenisBBM.isEmpty ||
        kuantum <= 0;

    if (basicValidation) {
      String errorDetails = 'Data dasar tidak valid: ';
      if (noKupon.isEmpty) errorDetails += 'noKupon kosong, ';
      if (bulan < 1 || bulan > 12)
        errorDetails += 'bulan tidak valid ($bulan), ';
      if (tahun < 2000) errorDetails += 'tahun tidak valid ($tahun), ';
      if (satker.isEmpty) errorDetails += 'satker kosong, ';
      if (jenisBBM.isEmpty) errorDetails += 'jenisBBM kosong, ';
      if (kuantum <= 0) errorDetails += 'kuantum tidak valid ($kuantum), ';

      throw Exception(errorDetails.replaceAll(RegExp(r', $'), ''));
    }

    // Validasi khusus untuk RANJEN - memerlukan data kendaraan lengkap
    if (!isDukungan) {
      if (jenisRanmor.isEmpty || noPol == null) {
        throw Exception('Data kendaraan tidak lengkap untuk kupon RANJEN');
      }
    }

    // Untuk DUKUNGAN, jenisRanmor boleh kosong, akan diisi default
    final finalJenisRanmor = isDukungan && jenisRanmor.isEmpty
        ? 'N/A (DUKUNGAN)'
        : jenisRanmor;

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

    // Get satkerId from database
    final db = await _databaseDatasource.database;
    final satkerResult = await db.query(
      'dim_satker',
      where: 'nama_satker = ?',
      whereArgs: [satker],
      limit: 1,
    );

    final satkerId = satkerResult.isNotEmpty
        ? satkerResult.first['satker_id'] as int
        : 1;

    // Hanya buat KendaraanModel untuk kupon RANJEN
    KendaraanModel? kendaraan;
    if (!isDukungan && noPol != null) {
      print(
        'Debug - Creating KendaraanModel for RANJEN with noPolNomor: "$noPol"',
      );
      kendaraan = KendaraanModel(
        kendaraanId: 0,
        satkerId: satkerId,
        jenisRanmor: finalJenisRanmor,
        noPolKode: finalKodeNopol,
        noPolNomor: noPol, // Gunakan angka yang sudah diextract
        statusAktif: 1,
        createdAt: DateTime.now().toIso8601String(),
      );
    } else {
      print('Debug - Skipping KendaraanModel creation for DUKUNGAN');
    }

    // Tentukan jenis BBM ID
    int jenisBbmId = 1; // Default Pertamax
    if (jenisBBM.toLowerCase().contains('dex')) {
      jenisBbmId = 2;
    }

    final kupon = KuponModel(
      kuponId: 0,
      nomorKupon: noKupon,
      kendaraanId: isDukungan
          ? null
          : 0, // null untuk DUKUNGAN, 0 untuk RANJEN (akan di-set nanti)
      jenisBbmId: jenisBbmId,
      jenisKuponId: jenisKupon.toLowerCase().contains('ranjen') ? 1 : 2,
      bulanTerbit: bulan,
      tahunTerbit: tahun,
      tanggalMulai: tanggalMulai.toIso8601String(),
      tanggalSampai: tanggalSampai.toIso8601String(),
      kuotaAwal: kuantum,
      kuotaSisa: kuantum,
      satkerId: satkerId, // Gunakan satkerId yang didapat dari database
      namaSatker: satker,
      status: 'Aktif',
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
      isDeleted: 0,
    );

    return (kupon, kendaraan);
  }

  /// Handles duplicate replacement by removing existing kupon with same criteria
  /// Returns true if replacement happened, false if no duplicates found
}

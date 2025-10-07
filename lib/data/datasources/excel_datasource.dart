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
    // Validasi file sebelum parsing
    final file = File(filePath);

    // Cek apakah file ada
    if (!file.existsSync()) {
      throw Exception(
        'FILE TIDAK DITEMUKAN!\n\nFile "$filePath" tidak ada atau sudah dipindah.',
      );
    }

    // Cek ukuran file (max 50MB untuk safety)
    final fileSize = file.lengthSync();
    if (fileSize > 50 * 1024 * 1024) {
      throw Exception(
        'FILE TERLALU BESAR!\n\n'
        'Ukuran file: ${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB\n'
        'Maksimum: 50 MB\n\n'
        'Silakan pecah data menjadi beberapa file kecil.',
      );
    }

    // Cek ekstensi file
    final extension = filePath.toLowerCase();
    if (!extension.endsWith('.xlsx') && !extension.endsWith('.xls')) {
      throw Exception(
        'FORMAT FILE SALAH!\n\n'
        'File harus berformat Excel (.xlsx atau .xls)\n'
        'File Anda: ${extension.split('.').last.toUpperCase()}',
      );
    }

    // Warning khusus untuk file .xls (format lama)
    if (extension.endsWith('.xls')) {
      print(
        'WARNING: File format .xls detected. Recommend converting to .xlsx for better compatibility.',
      );
    }

    late final bytes;
    late final Excel excel;

    try {
      bytes = File(filePath).readAsBytesSync();
    } catch (e) {
      throw Exception(
        'GAGAL MEMBACA FILE!\n\nError: ${e.toString()}\n\nPastikan file tidak sedang dibuka di aplikasi lain.',
      );
    }

    try {
      excel = Excel.decodeBytes(bytes);
    } catch (e) {
      final errorMsg = e.toString().toLowerCase();

      if (errorMsg.contains('numfmtid') || errorMsg.contains('format')) {
        throw Exception(
          'FORMAT EXCEL TIDAK KOMPATIBEL!\n\n'
          'Solusi:\n'
          '1. Buka file Excel Anda\n'
          '2. Pilih File > Save As\n'
          '3. Pilih format "Excel Workbook (.xlsx)"\n'
          '4. Pastikan tidak ada formatting khusus (conditional formatting, custom number formats)\n'
          '5. Coba import ulang\n\n'
          'Atau gunakan template yang disediakan aplikasi.',
        );
      } else if (errorMsg.contains('password') ||
          errorMsg.contains('encrypted')) {
        throw Exception(
          'FILE EXCEL TERPROTEKSI!\n\n'
          'File Excel ini memiliki password atau enkripsi.\n'
          'Silakan hapus proteksi terlebih dahulu sebelum import.',
        );
      } else if (errorMsg.contains('corrupted') ||
          errorMsg.contains('invalid')) {
        throw Exception(
          'FILE EXCEL RUSAK!\n\n'
          'File Excel tidak dapat dibaca. Kemungkinan file rusak.\n'
          'Silakan gunakan file backup atau buat ulang file Excel.',
        );
      } else if (errorMsg.contains('version') ||
          errorMsg.contains('unsupported')) {
        throw Exception(
          'VERSI EXCEL TIDAK DIDUKUNG!\n\n'
          'Solusi:\n'
          '1. Buka file dengan Excel/LibreOffice terbaru\n'
          '2. Save As dengan format .xlsx (Excel 2007+)\n'
          '3. Hindari format .xls (Excel 97-2003)\n'
          '4. Coba import ulang',
        );
      } else {
        throw Exception(
          'GAGAL MEMBACA FILE EXCEL!\n\n'
          'Error: ${e.toString()}\n\n'
          'Solusi umum:\n'
          '1. Pastikan file berformat .xlsx\n'
          '2. Tutup file Excel jika sedang terbuka\n'
          '3. Periksa ukuran file (max 50MB)\n'
          '4. Gunakan template yang disediakan\n'
          '5. Coba save ulang dengan Excel/LibreOffice terbaru',
        );
      }
    }

    // Validasi sheet availability
    if (excel.tables.isEmpty) {
      throw Exception(
        'FILE EXCEL KOSONG!\n\n'
        'File Excel tidak memiliki sheet atau data.\n'
        'Pastikan file memiliki minimal satu sheet dengan data kupon.',
      );
    }

    final sheetNames = excel.tables.keys.toList();
    print('DEBUG: Available sheets: $sheetNames');

    final kupons = <KuponModel>[];
    final newKendaraans = <KendaraanModel>[];
    final duplicateKupons = <KuponModel>[];
    final duplicateKendaraans = <KendaraanModel>[];
    final validationMessages = <String>[];

    // Temporary ID counter untuk kendaraan baru (dimulai dari -1 dan turun)
    // Ini akan di-map ke real ID nanti di enhanced_import_service.dart
    int tempKendaraanIdCounter = -1;
    final Map<String, int> tempKendaraanIdMap =
        {}; // key: noPolKode+noPolNomor, value: tempId

    // Ambil sheet pertama
    final sheet = excel.tables[excel.tables.keys.first]!;

    // Validasi sheet memiliki data
    if (sheet.rows.isEmpty) {
      throw Exception(
        'SHEET KOSONG!\n\n'
        'Sheet "${excel.tables.keys.first}" tidak memiliki data.\n'
        'Pastikan sheet memiliki data kupon yang valid.',
      );
    }

    print(
      'DEBUG: Sheet "${excel.tables.keys.first}" has ${sheet.rows.length} rows',
    );

    // Debug: Show first few rows
    for (int i = 0; i < (sheet.rows.length > 5 ? 5 : sheet.rows.length); i++) {
      final row = sheet.rows[i];
      final preview = row
          .map((cell) => cell?.value?.toString() ?? 'NULL')
          .take(5)
          .join(' | ');
      print('DEBUG - Row ${i + 1} preview: $preview');
    }

    // Langsung proses semua baris sebagai data (tanpa header)
    int processedRows = 0;

    for (int i = 0; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      final rowNumber = i + 1;
      try {
        // Parse data dari row
        final data = await _parseRow(
          row,
          tempKendaraanIdMap,
          () => --tempKendaraanIdCounter,
        );
        if (data != null) {
          processedRows++;
          final (kupon, kendaraan) = data;
          print(
            'DEBUG - Row $rowNumber -> Kupon: ${kupon.nomorKupon} (${kupon.jenisKuponId == 1 ? "RANJEN" : "DUKUNGAN"})',
          );

          // SOLUSI: Improved validation with better error categorization
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
            'DEBUG - Row $rowNumber: Kupon ${kupon.nomorKupon} (${kupon.namaSatker}, ${kupon.jenisKuponId == 1 ? "RANJEN" : "DUKUNGAN"}): ${validationResult.isValid}',
          );
          if (!validationResult.isValid) {
            print('DEBUG - Validation messages: ${validationResult.messages}');
            // Cari kupon yang sama di batch saat ini
            final sameInBatch = kupons
                .where(
                  (k) =>
                      k.nomorKupon == kupon.nomorKupon &&
                      k.satkerId == kupon.satkerId &&
                      k.bulanTerbit == kupon.bulanTerbit &&
                      k.tahunTerbit == kupon.tahunTerbit &&
                      k.jenisKuponId == kupon.jenisKuponId,
                )
                .toList();
            if (sameInBatch.isNotEmpty) {
              print(
                'DEBUG - Found ${sameInBatch.length} identical kupons already in current batch',
              );
            }
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
              // Analisis jenis duplikat - dari database atau batch saat ini
              final duplicateMessage = validationResult.messages.first;
              print('  -> Detail duplikat: $duplicateMessage');

              // Ini duplikat - masukkan ke list duplikat untuk preview
              duplicateKupons.add(kupon);
              if (kendaraan != null) {
                duplicateKendaraans.add(kendaraan);
              }
              validationMessages.add(
                'Baris $rowNumber: DUPLIKAT - ${validationResult.messages.join(", ")}',
              );
            } else {
              // PERBAIKAN: Kategorikan error - beberapa bisa diabaikan untuk tetap melanjutkan proses
              final isCriticalError = validationResult.messages.any(
                (msg) =>
                    msg.toLowerCase().contains('tidak valid') ||
                    msg.toLowerCase().contains('kosong') ||
                    msg.toLowerCase().contains('format'),
              );

              if (isCriticalError) {
                // Error kritis - skip kupon ini
                validationMessages.addAll(
                  validationResult.messages.map(
                    (msg) => 'Baris $rowNumber: CRITICAL ERROR - $msg',
                  ),
                );
              } else {
                // Non-critical error - bisa tetap diproses dengan warning
                validationMessages.addAll(
                  validationResult.messages.map(
                    (msg) => 'Baris $rowNumber: WARNING - $msg',
                  ),
                );

                // Tetap tambahkan ke list untuk diproses
                kupons.add(kupon);
                if (kendaraan != null) {
                  newKendaraans.add(kendaraan);
                }
              }
            }
          } else {
            // Validasi berhasil - tapi lakukan double-check duplikasi internal dengan mempertimbangkan ranmor
            bool existsInBatch;

            // Cek duplikat identik (semua field sama)
            existsInBatch = kupons.any(
              (k) =>
                  k.nomorKupon == kupon.nomorKupon &&
                  k.satkerId == kupon.satkerId &&
                  k.bulanTerbit == kupon.bulanTerbit &&
                  k.tahunTerbit == kupon.tahunTerbit &&
                  k.jenisKuponId == kupon.jenisKuponId &&
                  k.jenisBbmId == kupon.jenisBbmId &&
                  k.kendaraanId == kupon.kendaraanId &&
                  k.kuotaAwal == kupon.kuotaAwal,
            );

            if (existsInBatch) {
              print(
                'DEBUG - INTERNAL DUPLICATE DETECTED: Kupon ${kupon.nomorKupon} (${kupon.namaSatker})',
              );

              // Cari kupon yang benar-benar identik untuk analisis detail
              final existingKupon = kupons.firstWhere(
                (k) =>
                    k.nomorKupon == kupon.nomorKupon &&
                    k.satkerId == kupon.satkerId &&
                    k.bulanTerbit == kupon.bulanTerbit &&
                    k.tahunTerbit == kupon.tahunTerbit &&
                    k.jenisKuponId == kupon.jenisKuponId &&
                    k.jenisBbmId == kupon.jenisBbmId &&
                    k.kendaraanId == kupon.kendaraanId &&
                    k.kuotaAwal == kupon.kuotaAwal,
              );

              // Bandingkan detail
              final differences = <String>[];
              if (existingKupon.kuotaAwal != kupon.kuotaAwal) {
                differences.add(
                  'kuota: ${existingKupon.kuotaAwal} vs ${kupon.kuotaAwal}',
                );
              }
              if (existingKupon.jenisBbmId != kupon.jenisBbmId) {
                differences.add(
                  'BBM: ${existingKupon.jenisBbmId} vs ${kupon.jenisBbmId}',
                );
              }
              if (existingKupon.kendaraanId != kupon.kendaraanId) {
                differences.add(
                  'kendaraan: ${existingKupon.kendaraanId} vs ${kupon.kendaraanId}',
                );
              }

              // Tambahan info untuk RANJEN
              if (kupon.jenisKuponId == 1) {
                print('  -> RANJEN dengan kendaraanId: ${kupon.kendaraanId}');
              }

              if (differences.isEmpty) {
                print('  -> IDENTIK 100% - duplikat murni');
              } else {
                print(
                  '  -> Ada perbedaan: ${differences.join(', ')} - mungkin bukan duplikat sejati',
                );
              }

              duplicateKupons.add(kupon);
              if (kendaraan != null) {
                duplicateKendaraans.add(kendaraan);
              }
              validationMessages.add(
                'Baris $rowNumber: DUPLIKAT INTERNAL - Kupon ${kupon.nomorKupon} untuk ${kupon.namaSatker} sudah ada dalam batch ini',
              );
            } else {
              // Benar-benar kupon baru - tambahkan ke list
              kupons.add(kupon);
              if (kendaraan != null) {
                newKendaraans.add(kendaraan);
              }
            }
          }
        }
      } catch (e) {
        validationMessages.add('Error pada baris $rowNumber: ${e.toString()}');
      }
    }

    final skippedRows = sheet.rows.length - processedRows;

    print('DEBUG - EXCEL PARSING SUMMARY:');
    print('  📄 Total rows in Excel: ${sheet.rows.length}');
    print('  ✅ Rows successfully parsed: $processedRows');
    print('  ❌ Rows skipped/failed: $skippedRows');
    print('  📝 Valid kupons created: ${kupons.length}');
    print('  🔄 Duplicate kupons found: ${duplicateKupons.length}');
    print(
      '  📊 Total kupons detected: ${kupons.length + duplicateKupons.length}',
    );

    if (skippedRows > 0) {
      print(
        '  ⚠️ WARNING: $skippedRows rows were not processed - check for data formatting issues!',
      );
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

  Future<(KuponModel, KendaraanModel?)?> _parseRow(
    List<Data?> row,
    Map<String, int> tempKendaraanIdMap,
    int Function() getNextTempId,
  ) async {
    if (row.isEmpty || row.length < 10) return null;

    // Skip empty rows or headers
    final cell0 = _getCellString(row, 0);
    final cell1 = _getCellString(row, 1);

    // Skip if both first and second columns are empty
    if (cell0.isEmpty && cell1.isEmpty) {
      print('Debug - Skipping empty row (both cols empty)');
      return null;
    }

    // Skip if it looks like a header - hanya skip header yang jelas
    final cell0Lower = cell0.toLowerCase();
    final cell1Lower = cell1.toLowerCase();

    // Hanya skip jika ini benar-benar header bukan data
    final isDefinitelyHeader =
        ((cell0Lower == 'jenis' || cell0Lower == 'jenis kupon') &&
            (cell1Lower.contains('no') || cell1Lower.contains('nomor'))) ||
        (cell0Lower == 'type' && cell1Lower == 'number') ||
        (
        // Skip baris yang hanya berisi nama kolom saja
        (cell0Lower == 'ranjen' || cell0Lower == 'dukungan') &&
            (cell1Lower.isEmpty || cell1Lower == '-'));

    if (isDefinitelyHeader) {
      print('Debug - Skipping confirmed header row: "$cell0", "$cell1"');
      return null;
    }

    // Skip hanya jika kedua kolom pertama benar-benar kosong
    if (cell0.trim().isEmpty && cell1.trim().isEmpty) {
      print('Debug - Skipping completely empty row');
      return null;
    }

    // Jika salah satu kosong, coba tetap proses (mungkin ada data di kolom lain)
    if (cell0.trim().isEmpty || cell1.trim().isEmpty) {
      print(
        'Warning - Incomplete data in row: jenisKupon="$cell0", noKupon="$cell1" - will try to process',
      );
    }

    // Hanya skip jika benar-benar baris numbering yang tidak relevan
    if (RegExp(r'^\d+$').hasMatch(cell0) &&
        cell1.trim().isEmpty &&
        row.length < 5) {
      print('Debug - Skipping numbering row: "$cell0" (insufficient columns)');
      return null;
    }

    final jenisKupon = cell0;
    print('Debug - Processing row with jenisKupon: "$jenisKupon"');

    // Validasi jenis kupon lebih permisif
    final jenisKuponLower = jenisKupon.toLowerCase();
    if (!jenisKuponLower.contains('ranjen') &&
        !jenisKuponLower.contains('dukungan') &&
        !jenisKuponLower.contains('1') &&
        !jenisKuponLower.contains('2')) {
      print(
        'Warning - Jenis kupon tidak standar: "$jenisKupon" - akan dicoba tetap diproses',
      );
    }

    // No Kupon - DIPERBAIKI untuk handle berbagai format
    final noKuponStr = _getCellString(row, 1);
    print('Debug - Raw noKupon: "$noKuponStr"');

    if (noKuponStr.isEmpty) {
      print('Warning - No Kupon kosong, akan skip row ini');
      return null; // Return null instead of throwing exception
    }

    // Coba extract angka dari string
    final match = RegExp(r'\d+').firstMatch(noKuponStr);
    if (match == null) {
      print(
        'Warning - No Kupon tidak mengandung angka: "$noKuponStr" - akan skip',
      );
      return null; // Return null instead of throwing exception
    }
    final noKupon = match.group(0)!;

    // Bulan (romawi) - DIPERBAIKI
    final bulanStr = _getCellString(row, 2).toUpperCase();
    print('Debug - Bulan raw: "$bulanStr"'); // Debug line

    final bulanClean = RegExp(r'[IVXLCDM]+').stringMatch(bulanStr) ?? '';
    final bulan = _parseRomanNumeral(bulanClean);
    if (bulan == null) {
      print('Warning - Format bulan tidak valid: "$bulanStr" - akan skip');
      return null; // Return null instead of throwing exception
    }

    final tahunStr = _getCellString(row, 3);
    final tahun = int.tryParse(tahunStr) ?? 0;
    if (tahun == 0 || tahun < 2000) {
      print('Warning - Tahun tidak valid: "$tahunStr" - akan skip');
      return null; // Return null instead of throwing exception
    }

    final jenisRanmor = _getCellString(row, 4);
    final satkerRaw = _getCellString(row, 5);

    // Untuk DUKUNGAN dengan satker kosong, otomatis set sebagai CADANGAN
    final isDukunganCheck = jenisKupon.toLowerCase().contains('dukungan');
    String satker;
    if (isDukunganCheck &&
        (satkerRaw.isEmpty ||
            satkerRaw.toLowerCase() == 'null' ||
            satkerRaw == '-')) {
      satker = 'CADANGAN';
      print(
        'Debug - Auto-assigned CADANGAN for empty satker in DUKUNGAN kupon',
      );
    } else {
      satker = satkerRaw;
    }

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
    if (!jenisBBMLower.contains('pertamax') && !jenisBBMLower.contains('dex')) {
      throw Exception(
        'Jenis BBM harus mengandung kata Pertamax atau Dex. Ditemukan: "$jenisBBM"',
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

    int satkerId;
    if (satkerResult.isNotEmpty) {
      satkerId = satkerResult.first['satker_id'] as int;
    } else {
      // Jika satker tidak ditemukan, buat entry baru
      // Terutama untuk CADANGAN DUKUNGAN
      satkerId = await db.insert('dim_satker', {'nama_satker': satker});
      print('Created new satker: $satker with ID: $satkerId');
    }

    // Hanya buat KendaraanModel untuk kupon RANJEN
    KendaraanModel? kendaraan;
    int? tempKendaraanId;

    if (!isDukungan && noPol != null) {
      print(
        'Debug - Creating KendaraanModel for RANJEN with noPolNomor: "$noPol"',
      );

      // Generate unique key untuk kendaraan ini
      final kendaraanKey = '$finalKodeNopol$noPol';

      // Cek apakah kendaraan ini sudah pernah di-create (untuk duplikat nopol)
      if (tempKendaraanIdMap.containsKey(kendaraanKey)) {
        tempKendaraanId = tempKendaraanIdMap[kendaraanKey];
        print(
          'Debug - Reusing existing temp ID $tempKendaraanId for kendaraan: $kendaraanKey',
        );
      } else {
        tempKendaraanId = getNextTempId();
        tempKendaraanIdMap[kendaraanKey] = tempKendaraanId;
        print(
          'Debug - Generated new temp ID $tempKendaraanId for kendaraan: $kendaraanKey',
        );
      }

      kendaraan = KendaraanModel(
        kendaraanId: tempKendaraanId!,
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
          : tempKendaraanId, // null untuk DUKUNGAN, tempId untuk RANJEN
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

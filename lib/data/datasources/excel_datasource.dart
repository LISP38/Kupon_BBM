import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:kupon_bbm_app/data/datasources/database_datasource.dart';
import 'package:kupon_bbm_app/data/models/kupon_model.dart';
import 'package:kupon_bbm_app/data/models/kendaraan_model.dart';
// import 'package:kupon_bbm_app/data/validators/kupon_validator.dart'; // Validator lama tidak digunakan lagi

// class KuponValidator { // Tidak digunakan lagi dalam parseExcelFile
//   ...
// }

class ExcelParseResult {
  final List<KuponModel> kupons; // Kupons baru dari parsing (sudah dipisahkan dari duplikat database)
  final List<KendaraanModel> newKendaraans; // Kendaraan baru dari kupons
  final List<KuponModel>
      duplicateKupons; // Kupons yang duplikat terhadap data LAMA di database
  final List<KendaraanModel> duplicateKendaraans; // Kendaraan yang duplikat terhadap data LAMA di database
  final List<String> validationMessages; // Pesan-pesan validasi

  ExcelParseResult({
    required this.kupons,
    required this.newKendaraans,
    required this.duplicateKupons,
    required this.duplicateKendaraans,
    required this.validationMessages,
  });
}

class ExcelDatasource {
  // final KuponValidator _kuponValidator; // Tidak digunakan lagi
  final DatabaseDatasource _databaseDatasource;
  static const String DEFAULT_KODE_NOPOL = 'VIII';

  ExcelDatasource(
      // this._kuponValidator, // Tidak digunakan lagi
      this._databaseDatasource);

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

  // Fungsi untuk membuat kunci unik berdasarkan kombinasi field (untuk duplikat terhadap database lama)
  // Kombinasi ini mencerminkan kebijakan bahwa entitas kupon di database
  // ditentukan oleh nomor, jenis, satker, bulan, dan tahun terbit.
  String _generateUniqueKey(KuponModel kupon) {
    return "${kupon.nomorKupon}_${kupon.jenisKuponId}_${kupon.satkerId}_${kupon.bulanTerbit}_${kupon.tahunTerbit}";
  }

  // Fungsi untuk membuat kunci unik berdasarkan SELURUH field KuponModel (untuk duplikat internal dalam file)
  // Ini digunakan untuk mendeteksi entri yang benar-benar identik dalam satu file.
  // Kita masukkan semua field yang relevan dari KuponModel, termasuk yang bisa berbeda seperti jenisBbmId, kuotaAwal.
  String _generateFullUniqueKey(KuponModel kupon) {
    // Gabungkan semua field penting dari KuponModel
    // Perhatikan bahwa kuponId bisa 0 untuk entri baru, jadi mungkin tidak termasuk
    // createdAt dan updatedAt bisa berbeda saat parsing, jadi mungkin tidak termasuk
    // isDeleted diasumsikan 0
    // Gunakan field-field yang merepresentasikan data kupon itu sendiri
    // Urutan dan isi harus konsisten agar entri identik menghasilkan string yang sama
    return [
      kupon.nomorKupon,
      kupon.kendaraanId?.toString() ?? 'null', // Jika null, gunakan string 'null'
      kupon.jenisBbmId.toString(),
      kupon.jenisKuponId.toString(),
      kupon.bulanTerbit.toString(),
      kupon.tahunTerbit.toString(),
      kupon.tanggalMulai,
      kupon.tanggalSampai,
      kupon.kuotaAwal.toString(),
      kupon.kuotaSisa.toString(),
      kupon.satkerId.toString(),
      kupon.namaSatker,
      kupon.status,
      // createdAt dan updatedAt tidak termasuk karena bisa berbeda setiap insert
      // isDeleted diasumsikan 0 untuk data baru
    ].join('|');
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

    late final Uint8List bytes;
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

    // Langsung proses semua baris sebagai data (tanpa header)
    int processedRows = 0;

    // Buat set kunci unik dari existingKupons untuk pencarian cepat
    final existingUniqueKeys = <String>{};
    for (final k in existingKupons) {
      existingUniqueKeys.add(_generateUniqueKey(k));
    }

    for (int i = 0; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      final rowNumber = i + 1;
      try {
        // Parse data dari row
        final data = await _parseRow(row);
        if (data != null) {
          processedRows++;
          final (kupon, kendaraan) = data;
          print(
            'DEBUG - Row $rowNumber -> Kupon: ${kupon.nomorKupon} (${kupon.jenisKuponId == 1 ? "RANJEN" : "DUKUNGAN"})',
          );

          // Buat kunci unik untuk kupon yang sedang diproses (untuk cek duplikat terhadap database lama)
          final uniqueKey = _generateUniqueKey(kupon);

          // Cek apakah kupon ini duplikat terhadap existingKupons
          if (existingUniqueKeys.contains(uniqueKey)) {
            duplicateKupons.add(kupon);
            if (kendaraan != null) {
              duplicateKendaraans.add(kendaraan);
            }
            validationMessages.add(
              'Baris $rowNumber: DUPLIKAT terhadap data yang sudah ada di sistem - Kupon ${kupon.nomorKupon} (${kupon.jenisKuponId == 1 ? "RANJEN" : "DUKUNGAN"}) untuk ${kupon.namaSatker} di bulan ${kupon.bulanTerbit}/${kupon.tahunTerbit}.',
            );
          } else {
            // Kupon ini bukan duplikat terhadap existing, tambahkan ke list sementara
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

    print(
      'DEBUG - Total rows processed: $processedRows out of ${sheet.rows.length} rows',
    );
    print('DEBUG - Final kupon count: ${kupons.length}');
    print('DEBUG - Final duplicate count: ${duplicateKupons.length}');
    print('DEBUG - Total expected: ${kupons.length + duplicateKupons.length}');

    // --- Logika untuk menangani duplikat INTERNAL dalam file ---
    // Kita ingin mendeteksi dan memisahkan entri yang BENAR-BENAR IDENTIK dalam file yang sama
    // Kita gunakan _generateFullUniqueKey untuk membuat kunci berdasarkan SEMUA field KuponModel
    final seenFullKeysInFile = <String>{};
    final uniqueKupons = <KuponModel>[];
    final uniqueKendaraans = <KendaraanModel>[];
    final inFileDuplicateKupons = <KuponModel>[];
    final inFileDuplicateKendaraans = <KendaraanModel>[];

    for (int i = 0; i < kupons.length; i++) {
      final k = kupons[i];
      final kendaraan = i < newKendaraans.length ? newKendaraans[i] : null;
      // Gunakan kunci yang mencakup SEMUA field untuk mendeteksi duplikat internal
      final fullUniqueKey = _generateFullUniqueKey(k);

      if (seenFullKeysInFile.contains(fullUniqueKey)) {
        // Duplikat internal dalam file (benar-benar identik)
        print('DEBUG: Found internal duplicate at index $i with key: $fullUniqueKey');
        inFileDuplicateKupons.add(k);
        if (kendaraan != null) inFileDuplicateKendaraans.add(kendaraan);
      } else {
        seenFullKeysInFile.add(fullUniqueKey);
        uniqueKupons.add(k);
        if (kendaraan != null) uniqueKendaraans.add(kendaraan);
      }
    }

    // Tambahkan ke pesan validasi
    if (inFileDuplicateKupons.isNotEmpty) {
      validationMessages.add(
        'Terdeteksi ${inFileDuplicateKupons.length} entri benar-benar identik di dalam file Excel yang sama.',
      );
    }

    // Setelah parsing dan validasi, simpan ke database
    // Sekarang, uniqueKupons seharusnya berisi SEMUA entri dari file
    // kecuali yang benar-benar identik satu sama lain.
    if (uniqueKupons.isNotEmpty) {
      await _databaseDatasource.insertKupons(uniqueKupons);
    }

    return ExcelParseResult(
      kupons: uniqueKupons, // Gunakan yang unik dalam file (tidak benar-benar identik)
      newKendaraans: uniqueKendaraans,
      duplicateKupons: [...duplicateKupons, ...inFileDuplicateKupons], // Gabungkan semua duplikat
      duplicateKendaraans: [
        ...duplicateKendaraans,
        ...inFileDuplicateKendaraans,
      ],
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
      print('Debug - Skipping empty row (both cols empty)');
      return null;
    }

    // Skip if it looks like a header row
    final cell0Lower = cell0.toLowerCase();
    final cell1Lower = cell1.toLowerCase();

    // Hanya skip baris yang memang berisi kata "Jenis Kupon" atau "No Kupon"
    final isHeaderRow =
        (cell0Lower.contains('jenis') && cell0Lower.contains('kupon')) ||
        (cell1Lower.contains('no') && cell1Lower.contains('kupon')) ||
        (cell1Lower.contains('nomor') && cell1Lower.contains('kupon'));

    if (isHeaderRow) {
      print('Debug - Skipping header row: "$cell0", "$cell1"');
      return null;
    }

    // Skip jika baris tidak memiliki data minimal (noKupon)
    if (cell1.trim().isEmpty) {
      print('Debug - Skipping incomplete row: noKupon="$cell1"');
      return null;
    }

    // Skip baris yang hanya berisi angka atau teks formatting
    if (RegExp(r'^\d+$').hasMatch(cell0) && cell1.trim().isEmpty) {
      print('Debug - Skipping formatting/numbering row: "$cell0"');
      return null;
    }

    // Jenis Kupon - NULLABLE (boleh kosong)
    final jenisKupon = cell0.isNotEmpty ? cell0 : 'DUKUNGAN';
    print('Debug - Jenis Kupon: "$jenisKupon"');

    // No Kupon - REQUIRED
    final noKuponStr = _getCellString(row, 1);
    print('Debug - No Kupon raw: "$noKuponStr"');

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
    print('Debug - Bulan raw: "$bulanStr"');

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

    // Jenis Ranmor - NULLABLE (boleh kosong)
    final jenisRanmor = _getCellString(row, 4);
    print(
      'Debug - Jenis Ranmor: "${jenisRanmor.isEmpty ? "NULL" : jenisRanmor}"',
    );

    // Satker - NORMALIZED (selalu konsisten huruf besar, tanpa spasi)
    final satkerRaw = _getCellString(row, 5).trim();
    String satker;

    if (satkerRaw.isEmpty ||
        satkerRaw.toLowerCase() == 'null' ||
        satkerRaw == '-') {
      satker = 'CADANGAN';
      print('Debug - Satker kosong/null, diubah jadi: "CADANGAN"');
    } else {
      satker = satkerRaw.toUpperCase();
    }

    // No Pol - NULLABLE (boleh kosong)
    final noPolStr = _getCellString(row, 6);
    print('Debug - No Pol raw: "${noPolStr.isEmpty ? "NULL" : noPolStr}"');

    String? noPol;
    if (noPolStr.isNotEmpty) {
      // Extract angka dari No Pol
      final noPolMatch = RegExp(r'\d+').firstMatch(noPolStr);
      if (noPolMatch != null) {
        noPol = noPolMatch.group(0)!;
      }
    }

    // Kode Nopol - NULLABLE (boleh kosong)
    final kodeNopol = _getCellString(row, 7);
    print(
      'Debug - Kode Nopol: "${kodeNopol.isEmpty ? "NULL (akan gunakan default)" : kodeNopol}"',
    );

    final jenisBBM = _getCellString(row, 8);
    final kuantumStr = _getCellString(row, 9);
    final kuantum = double.tryParse(kuantumStr) ?? 0.0;

    print('Debug - Jenis BBM: "$jenisBBM"');
    print('Debug - Kuantum: "$kuantumStr" -> $kuantum');

    // Validasi jenis BBM dengan lebih fleksibel (nullable)
    if (jenisBBM.isNotEmpty) {
      final jenisBBMLower = jenisBBM.toLowerCase();
      if (!jenisBBMLower.contains('pertamax') &&
          !jenisBBMLower.contains('dex') &&
          !jenisBBMLower.contains('dexlite') &&
          !jenisBBMLower.contains('solar')) {
        throw Exception(
          'Jenis BBM harus mengandung kata Pertamax, Dex, Dexlite, atau Solar. Ditemukan: "$jenisBBM"',
        );
      }
    }

    // Validasi data lengkap
    print('Debug - Validasi Detail:');
    print('  noKupon: "$noKupon" (kosong: ${noKupon.isEmpty})');
    print('  bulan: $bulan (valid: ${bulan >= 1 && bulan <= 12})');
    print('  tahun: $tahun (valid: ${tahun >= 2000})');
    print('  satker: "$satker" (kosong: ${satker.isEmpty})');
    print('  kuantum: $kuantum (valid: ${kuantum > 0})');
    // jenisRanmor, noPol, kodeNopol are allowed to be empty/null

    final basicValidation =
        noKupon.isEmpty ||
        bulan < 1 ||
        bulan > 12 ||
        tahun < 2000 ||
        satker.isEmpty ||
        kuantum <= 0;

    if (basicValidation) {
      String errorDetails = 'Data dasar tidak valid: ';
      if (noKupon.isEmpty) errorDetails += 'noKupon kosong, ';
      if (bulan < 1 || bulan > 12) {
        errorDetails += 'bulan tidak valid ($bulan), ';
      }
      if (tahun < 2000) errorDetails += 'tahun tidak valid ($tahun), ';
      if (satker.isEmpty) errorDetails += 'satker kosong, ';
      if (kuantum <= 0) errorDetails += 'kuantum tidak valid ($kuantum), ';

      throw Exception(errorDetails.replaceAll(RegExp(r', $'), ''));
    }

    // Jenis Kupon untuk penentuan tipe
    final isDukungan = jenisKupon.toLowerCase().contains('dukungan');

    // Untuk DUKUNGAN, jenisRanmor boleh kosong, akan diisi default
    final finalJenisRanmor = (isDukungan && jenisRanmor.isEmpty)
        ? 'N/A (DUKUNGAN)'
        : jenisRanmor.isEmpty
        ? 'TIDAK DIISI'
        : jenisRanmor;

    final tanggalMulai = DateTime(tahun, bulan, 1);
    final tanggalSampai = DateTime(tahun, bulan + 1, 0);

    // Gunakan kode yang ada di Excel atau default
    final finalKodeNopol = kodeNopol.isNotEmpty
        ? kodeNopol
        : DEFAULT_KODE_NOPOL;

    // Get satkerId from database
    final db = await _databaseDatasource.database;
    final satkerResult = await db.query(
      'dim_satker',
      where: 'UPPER(TRIM(nama_satker)) = ?',
      whereArgs: [satker.trim().toUpperCase()],
      limit: 1,
    );

    int satkerId;
    if (satkerResult.isNotEmpty) {
      satkerId = satkerResult.first['satker_id'] as int;
    } else {
      // Jika satker tidak ditemukan, buat entry baru
      satkerId = await db.insert('dim_satker', {'nama_satker': satker});
      print('Created new satker: $satker with ID: $satkerId');
    }

    // Cari kendaraan di dim_kendaraan, jika belum ada, insert dan buat KendaraanModel
    KendaraanModel? kendaraan;
    int? kendaraanId;
    if (!isDukungan && noPol != null && noPol.isNotEmpty) {
      final kendaraanRow = await db.query(
        'dim_kendaraan',
        where:
            'satker_id = ? AND jenis_ranmor = ? AND no_pol_kode = ? AND no_pol_nomor = ?',
        whereArgs: [satkerId, finalJenisRanmor, finalKodeNopol, noPol],
        limit: 1,
      );
      if (kendaraanRow.isNotEmpty) {
        kendaraanId = kendaraanRow.first['kendaraan_id'] as int;
        kendaraan = null; // Sudah ada, tidak perlu buat baru
      } else {
        try {
          kendaraanId = await db.rawInsert(
            'INSERT OR IGNORE INTO dim_kendaraan (satker_id, jenis_ranmor, no_pol_kode, no_pol_nomor, status_aktif, created_at) VALUES (?, ?, ?, ?, ?, ?)',
            [
              satkerId,
              finalJenisRanmor,
              finalKodeNopol,
              noPol,
              1,
              DateTime.now().toIso8601String(),
            ],
          );
        } catch (e) {
          // Jika gagal karena UNIQUE constraint, fallback ke select
          final fallbackCheck = await db.query(
            'dim_kendaraan',
            where:
                'satker_id = ? AND jenis_ranmor = ? AND no_pol_kode = ? AND no_pol_nomor = ?',
            whereArgs: [satkerId, finalJenisRanmor, finalKodeNopol, noPol],
            limit: 1,
          );
          if (fallbackCheck.isNotEmpty) {
            kendaraanId = fallbackCheck.first['kendaraan_id'] as int;
            kendaraan = null;
          } else {
            rethrow;
          }
        }
        // Jika kendaraanId tetap null, cari lagi (harusnya tidak terjadi)
        if (kendaraanId == 0) {
          final finalCheck = await db.query(
            'dim_kendaraan',
            where:
                'satker_id = ? AND jenis_ranmor = ? AND no_pol_kode = ? AND no_pol_nomor = ?',
            whereArgs: [satkerId, finalJenisRanmor, finalKodeNopol, noPol],
            limit: 1,
          );
          if (finalCheck.isNotEmpty) {
            kendaraanId = finalCheck.first['kendaraan_id'] as int;
            kendaraan = null;
          } else {
            throw Exception(
              'Gagal menyisipkan kendaraan dan tidak ditemukan di database.',
            );
          }
        } else {
          kendaraan = KendaraanModel(
            kendaraanId: kendaraanId,
            satkerId: satkerId,
            jenisRanmor: finalJenisRanmor,
            noPolKode: finalKodeNopol,
            noPolNomor: noPol,
            statusAktif: 1,
            createdAt: DateTime.now().toIso8601String(),
          );
        }
      }
      // Validasi kendaraanId untuk kupon non-dukungan
      if (!isDukungan && kendaraanId == 0) {
        throw Exception(
          'Kupon Non-Dukungan memerlukan data Kendaraan (No Pol & Jenis Ranmor) yang valid, namun gagal dibuat/ditemukan.',
        );
      }
    }

    // Tentukan jenis BBM ID
    int jenisBbmId = 1; // Default Pertamax
    if (jenisBBM.isNotEmpty) {
      final jenisBBMLower = jenisBBM.toLowerCase();
      if (jenisBBMLower.contains('pertamina dex') ||
          jenisBBMLower.contains('dexlite') ||
          jenisBBMLower.contains('dex')) {
        jenisBbmId = 2;
      }
    }
    print(
      'DEBUG - jenisBbmId to insert: value=$jenisBbmId, type=${jenisBbmId.runtimeType}, from Jenis BBM="$jenisBBM"',
    );

    final kupon = KuponModel(
      kuponId: 0, // ID akan diisi oleh database saat insert
      nomorKupon: noKupon,
      kendaraanId: isDukungan ? null : kendaraanId,
      jenisBbmId: jenisBbmId,
      jenisKuponId: jenisKupon.toLowerCase().contains('ranjen') ? 1 : 2,
      bulanTerbit: bulan,
      tahunTerbit: tahun,
      tanggalMulai: tanggalMulai.toIso8601String(),
      tanggalSampai: tanggalSampai.toIso8601String(),
      kuotaAwal: kuantum,
      kuotaSisa: kuantum,
      satkerId: satkerId,
      namaSatker: satker,
      status: 'Aktif',
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
      isDeleted: 0,
    );

    return (kupon, kendaraan);
  }
}
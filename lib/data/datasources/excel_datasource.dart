import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:kupon_bbm_app/data/datasources/database_datasource.dart';
import 'package:kupon_bbm_app/data/models/kupon_model.dart';
import 'package:kupon_bbm_app/data/models/kendaraan_model.dart';

class ExcelParseResult {
  final List<KuponModel> kupons;
  final List<KendaraanModel> newKendaraans;
  final List<KuponModel> duplicateKupons;
  final List<KendaraanModel> duplicateKendaraans;
  final List<String> validationMessages;

  ExcelParseResult({
    required this.kupons,
    required this.newKendaraans,
    required this.duplicateKupons,
    required this.duplicateKendaraans,
    required this.validationMessages,
  });
}

class ExcelDatasource {
  final DatabaseDatasource _databaseDatasource;
  static const String DEFAULT_KODE_NOPOL = 'VIII';

  ExcelDatasource(this._databaseDatasource);

  String _normalizeSatkerName(String satkerName) {
    return satkerName
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .toUpperCase();
  }

  int? _parseRomanNumeral(String roman) {
    const romanValues = {
      'I': 1, 'II': 2, 'III': 3, 'IV': 4, 'V': 5,
      'VI': 6, 'VII': 7, 'VIII': 8, 'IX': 9, 'X': 10,
      'XI': 11, 'XII': 12,
    };
    return romanValues[roman.trim().toUpperCase()];
  }

  String _generateUniqueKey(KuponModel kupon) {
    return "${kupon.nomorKupon}_${kupon.jenisKuponId}_${kupon.satkerId}_${kupon.bulanTerbit}_${kupon.tahunTerbit}";
  }

  Future<ExcelParseResult> parseExcelFile(
    String filePath,
    List<KuponModel> existingKupons,
  ) async {
    // Validasi file
    final file = File(filePath);
    if (!file.existsSync()) {
      throw Exception('FILE TIDAK DITEMUKAN!\n\nFile "$filePath" tidak ada atau sudah dipindah.');
    }

    final fileSize = file.lengthSync();
    if (fileSize > 50 * 1024 * 1024) {
      throw Exception(
        'FILE TERLALU BESAR!\n\nUkuran file: ${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB\nMaksimum: 50 MB',
      );
    }

    final extension = filePath.toLowerCase();
    if (!extension.endsWith('.xlsx') && !extension.endsWith('.xls')) {
      throw Exception('FORMAT FILE SALAH!\n\nFile harus berformat Excel (.xlsx atau .xls)');
    }

    // Baca file Excel
    late final Uint8List bytes;
    late final Excel excel;
    try {
      bytes = File(filePath).readAsBytesSync();
      excel = Excel.decodeBytes(bytes);
    } catch (e) {
      final errorMsg = e.toString().toLowerCase();
      if (errorMsg.contains('numfmtid') || errorMsg.contains('format')) {
        throw Exception('FORMAT EXCEL TIDAK KOMPATIBEL!\n\nSolusi: Save As dengan format .xlsx');
      } else if (errorMsg.contains('password') || errorMsg.contains('encrypted')) {
        throw Exception('FILE EXCEL TERPROTEKSI!\n\nSilakan hapus proteksi terlebih dahulu.');
      } else {
        throw Exception('GAGAL MEMBACA FILE EXCEL!\n\nError: ${e.toString()}');
      }
    }

    if (excel.tables.isEmpty) {
      throw Exception('FILE EXCEL KOSONG!\n\nFile Excel tidak memiliki sheet atau data.');
    }

    final sheet = excel.tables[excel.tables.keys.first]!;
    if (sheet.rows.isEmpty) {
      throw Exception('SHEET KOSONG!\n\nSheet tidak memiliki data.');
    }

    print('DEBUG: Total rows in Excel: ${sheet.rows.length}');

    // Parsing data
    final kupons = <KuponModel>[];
    final newKendaraans = <KendaraanModel>[];
    final validationMessages = <String>[];

    for (int i = 0; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      final rowNumber = i + 1;
      try {
        final data = await _parseRow(row, rowNumber);
        if (data != null) {
          final (kupon, kendaraan) = data;
          kupons.add(kupon);
          if (kendaraan != null) {
            newKendaraans.add(kendaraan);
          }
        }
      } catch (e) {
        validationMessages.add('Error pada baris $rowNumber: ${e.toString()}');
        print('ERROR: Row $rowNumber - ${e.toString()}');
        continue;
      }
    }

    print('DEBUG: Total valid kupons parsed: ${kupons.length}');

    // Pemisahan duplikat dan unik
    final existingUniqueKeys = <String>{};
    for (final k in existingKupons) {
      existingUniqueKeys.add(_generateUniqueKey(k));
    }

    final seenKeysInFile = <String>{};
    final uniqueKupons = <KuponModel>[];
    final uniqueKendaraans = <KendaraanModel>[];
    final duplicateKupons = <KuponModel>[];
    final duplicateKendaraans = <KendaraanModel>[];

    for (int i = 0; i < kupons.length; i++) {
      final k = kupons[i];
      final kendaraan = i < newKendaraans.length ? newKendaraans[i] : null;

      final uniqueKey = _generateUniqueKey(k);

      if (existingUniqueKeys.contains(uniqueKey)) {
        duplicateKupons.add(k);
        if (kendaraan != null) duplicateKendaraans.add(kendaraan);
        validationMessages.add(
          'Baris ${i + 1}: DUPLIKAT terhadap data yang sudah ada di sistem - Kupon ${k.nomorKupon} (${k.jenisKuponId == 1 ? "RANJEN" : "DUKUNGAN"}) untuk ${k.namaSatker} di bulan ${k.bulanTerbit}/${k.tahunTerbit}.',
        );
      } else if (seenKeysInFile.contains(uniqueKey)) {
        duplicateKupons.add(k);
        if (kendaraan != null) duplicateKendaraans.add(kendaraan);
        validationMessages.add(
          'Baris ${i + 1}: DUPLIKAT INTERNAL di file Excel - Kupon ${k.nomorKupon} (${k.jenisKuponId == 1 ? "RANJEN" : "DUKUNGAN"}) untuk ${k.namaSatker} di bulan ${k.bulanTerbit}/${k.tahunTerbit}.',
        );
      } else {
        seenKeysInFile.add(uniqueKey);
        uniqueKupons.add(k);
        if (kendaraan != null) uniqueKendaraans.add(kendaraan);
      }
    }

    print('DEBUG: Total unique kupons to insert: ${uniqueKupons.length}');

    // Simpan data ke database
    if (uniqueKupons.isNotEmpty) {
      print('DEBUG: Starting database insert for ${uniqueKupons.length} kupons...');
      
      // Simpan kendaraan terlebih dahulu
      if (uniqueKendaraans.isNotEmpty) {
        print('DEBUG: Inserting ${uniqueKendaraans.length} kendaraans...');
        try {
          await _databaseDatasource.insertKendaraans(uniqueKendaraans);
        } catch (e) {
          print('ERROR: Failed to insert kendaraans: ${e.toString()}');
          validationMessages.add('Gagal menyimpan data kendaraan: ${e.toString()}');
        }
      }
      
      // Kemudian simpan kupon
      print('DEBUG: Inserting ${uniqueKupons.length} kupons...');
      try {
        await _databaseDatasource.insertKupons(uniqueKupons);
      } catch (e) {
        print('ERROR: Failed to insert kupons: ${e.toString()}');
        validationMessages.add('Gagal menyimpan data kupon: ${e.toString()}');
      }
    }

    return ExcelParseResult(
      kupons: uniqueKupons,
      newKendaraans: uniqueKendaraans,
      duplicateKupons: duplicateKupons,
      duplicateKendaraans: duplicateKendaraans,
      validationMessages: validationMessages,
    );
  }

  String _getCellString(List<Data?> row, int index) {
    if (index >= row.length) return '';
    final raw = row[index]?.value;
    if (raw == null) return '';
    return raw.toString().trim();
  }

  Future<(KuponModel, KendaraanModel?)?> _parseRow(
    List<Data?> row,
    int rowNumber,
  ) async {
    if (row.isEmpty || row.length < 10) {
      print('DEBUG: Skipping row $rowNumber - Not enough columns.');
      return null;
    }

    final cell0 = _getCellString(row, 0);
    final cell1 = _getCellString(row, 1);
    final cell2 = _getCellString(row, 2);
    final cell3 = _getCellString(row, 3);

    // Skip baris formatting atau header
    if (cell0 == '*' || cell1 == '*' || cell2 == '*' || cell3 == '*') {
      print('DEBUG: Skipping formatting row $rowNumber.');
      return null;
    }
    if (RegExp(r'^[\*\\-]+$').hasMatch(cell0) && RegExp(r'^[\*\\-]+$').hasMatch(cell1)) {
      print('DEBUG: Skipping dash/asterisk row $rowNumber.');
      return null;
    }
    if (cell0.isEmpty && cell1.isEmpty) {
      print('DEBUG: Skipping empty row $rowNumber.');
      return null;
    }
    if (cell0.isEmpty && cell1.isEmpty && cell2.isEmpty && cell3.isEmpty) {
      print('DEBUG: Skipping completely empty row $rowNumber.');
      return null;
    }

    final cell0Lower = cell0.toLowerCase();
    final cell1Lower = cell1.toLowerCase();
    final isHeaderRow =
        (cell0Lower.contains('jenis') && cell0Lower.contains('kupon')) ||
        (cell1Lower.contains('no') && cell1Lower.contains('kupon')) ||
        (cell1Lower.contains('nomor') && cell1Lower.contains('kupon'));
    if (isHeaderRow) {
      print('DEBUG: Skipping header row $rowNumber.');
      return null;
    }
    if (cell1.trim().isEmpty) {
      print('DEBUG: Skipping row $rowNumber - No Kupon is empty.');
      return null;
    }
    if (RegExp(r'^\d+$').hasMatch(cell0) && cell1.trim().isEmpty) {
      print('DEBUG: Skipping numbering row $rowNumber.');
      return null;
    }

    // Parsing data
    final jenisKupon = cell0.isNotEmpty ? cell0 : 'DUKUNGAN';
    final noKuponStr = _getCellString(row, 1);
    if (noKuponStr.isEmpty) throw Exception('No Kupon tidak boleh kosong');
    
    final match = RegExp(r'\d+').firstMatch(noKuponStr);
    if (match == null) {
      throw Exception('No Kupon harus mengandung angka. Ditemukan: "$noKuponStr"');
    }
    final noKupon = match.group(0)!;

    final bulanStr = _getCellString(row, 2).toUpperCase();
    final bulanClean = RegExp(r'[IVXLCDM]+').stringMatch(bulanStr) ?? '';
    final bulan = _parseRomanNumeral(bulanClean);
    if (bulan == null) {
      throw Exception('Format bulan tidak valid. Gunakan angka romawi (I-XII). Ditemukan: "$bulanStr"');
    }

    final tahunStr = _getCellString(row, 3);
    final tahun = int.tryParse(tahunStr) ?? 0;
    if (tahun == 0) {
      throw Exception('Tahun tidak valid. Ditemukan: "$tahunStr"');
    }

    final jenisRanmor = _getCellString(row, 4);
    final satkerRaw = _getCellString(row, 5);
    var satker = _normalizeSatkerName(satkerRaw);
    
    if (satker.isEmpty) {
      satker = 'CADANGAN';
    }

    final noPolStr = _getCellString(row, 6);
    String? noPol;
    if (noPolStr.isNotEmpty) {
      final noPolMatch = RegExp(r'\d+').firstMatch(noPolStr);
      if (noPolMatch != null) {
        noPol = noPolMatch.group(0)!;
      }
    }

    final kodeNopol = _getCellString(row, 7);
    final jenisBBM = _getCellString(row, 8);
    final kuantumStr = _getCellString(row, 9);
    final kuantum = double.tryParse(kuantumStr) ?? 0.0;

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
      if (bulan < 1 || bulan > 12) errorDetails += 'bulan tidak valid ($bulan), ';
      if (tahun < 2000) errorDetails += 'tahun tidak valid ($tahun), ';
      if (satker.isEmpty) errorDetails += 'satker kosong, ';
      if (kuantum <= 0) errorDetails += 'kuantum tidak valid ($kuantum), ';
      throw Exception(errorDetails.replaceAll(RegExp(r', $'), ''));
    }

    final isDukungan = jenisKupon.toLowerCase().contains('dukungan');
    
    // PERBAIKAN: Logika jenis ranmor yang lebih baik
    String finalJenisRanmor;
    if (isDukungan) {
      // Untuk kupon dukungan, gunakan N/A
      finalJenisRanmor = 'N/A (DUKUNGAN)';
    } else {
      // Untuk kupon ranjen, jenis ranmor HARUS diisi
      if (jenisRanmor.isEmpty) {
        throw Exception('Jenis Ranmor tidak boleh kosong untuk kupon RANJEN');
      }
      finalJenisRanmor = jenisRanmor;
    }
    
    final tanggalMulai = DateTime(tahun, bulan, 1);
    final tanggalSampai = DateTime(tahun, bulan + 1, 0);
    final finalKodeNopol = kodeNopol.isNotEmpty ? kodeNopol : DEFAULT_KODE_NOPOL;

    // Operasi Database
    final db = await _databaseDatasource.database;
    
    // Cari atau buat satker
    final satkerResult = await db.query(
      'dim_satker',
      where: 'UPPER(TRIM(nama_satker)) = ?',
      whereArgs: [satker],
      limit: 1,
    );
    
    int satkerId;
    if (satkerResult.isNotEmpty) {
      satkerId = satkerResult.first['satker_id'] as int;
    } else {
      satkerId = await db.insert('dim_satker', {'nama_satker': satker});
      print('Created new satker: $satker with ID: $satkerId');
    }

    KendaraanModel? kendaraan;
    int? kendaraanId;
    
    // PERBAIKAN: Untuk kupon RANJEN, wajib ada nomor polisi
    if (!isDukungan) {
      if (noPol == null || noPol.isEmpty) {
        throw Exception('Nomor Polisi tidak boleh kosong untuk kupon RANJEN');
      }
      
      // Cari kendaraan berdasarkan nomor polisi
      print('DEBUG: Looking for kendaraan with nopol $finalKodeNopol $noPol');
      
      final kendaraanRow = await db.query(
        'dim_kendaraan',
        where: 'no_pol_kode = ? AND no_pol_nomor = ?',
        whereArgs: [finalKodeNopol, noPol],
        limit: 1,
      );
      
      if (kendaraanRow.isNotEmpty) {
        kendaraanId = kendaraanRow.first['kendaraan_id'] as int;
        final existingSatkerId = kendaraanRow.first['satker_id'] as int;
        
        // Jika kendaraan ditemukan dengan satker yang berbeda, log peringatan
        if (existingSatkerId != satkerId) {
          print('WARNING: Kendaraan dengan nopol $finalKodeNopol $noPol sudah terdaftar di satker lain (ID: $existingSatkerId), menggunakan kendaraan yang ada (ID: $kendaraanId)');
          
          // Ambil nama satker asli untuk ditampilkan di log
          final existingSatkerRow = await db.query(
            'dim_satker',
            where: 'satker_id = ?',
            whereArgs: [existingSatkerId],
            limit: 1,
          );
          
          if (existingSatkerRow.isNotEmpty) {
            final existingSatkerName = existingSatkerRow.first['nama_satker'] as String;
            print('WARNING: Kendaraan $finalKodeNopol $noPol seharusnya milik satker $existingSatkerName, bukan $satker');
          }
        } else {
          print('DEBUG: Found existing kendaraan with ID: $kendaraanId for satker $satker');
        }
      } else {
        // Buat kendaraan baru
        try {
          print('DEBUG: Inserting new kendaraan for satker $satkerId, jenis $finalJenisRanmor, nopol $finalKodeNopol $noPol');
          
          final kendaraanData = {
            'satker_id': satkerId,
            'jenis_ranmor': finalJenisRanmor,
            'no_pol_kode': finalKodeNopol,
            'no_pol_nomor': noPol,
            'status_aktif': 1,
            'created_at': DateTime.now().toIso8601String(),
          };
          
          kendaraanId = await db.insert('dim_kendaraan', kendaraanData);
          
          if (kendaraanId > 0) {
            print('DEBUG: Successfully created new kendaraan with ID: $kendaraanId');
            kendaraan = KendaraanModel(
              kendaraanId: kendaraanId,
              satkerId: satkerId,
              jenisRanmor: finalJenisRanmor,
              noPolKode: finalKodeNopol,
              noPolNomor: noPol,
              statusAktif: 1,
              createdAt: DateTime.now().toIso8601String(),
            );
          } else {
            throw Exception('Gagal menyisipkan kendaraan, returned ID: $kendaraanId');
          }
        } catch (e) {
          print('ERROR: Exception when inserting kendaraan: ${e.toString()}');
          
          // Coba cari lagi untuk memastikan tidak ada race condition
          final fallbackCheck = await db.query(
            'dim_kendaraan',
            where: 'no_pol_kode = ? AND no_pol_nomor = ?',
            whereArgs: [finalKodeNopol, noPol],
            limit: 1,
          );
          
          if (fallbackCheck.isNotEmpty) {
            kendaraanId = fallbackCheck.first['kendaraan_id'] as int;
            print('DEBUG: Found kendaraan on fallback check with ID: $kendaraanId');
          } else {
            rethrow;
          }
        }
      }
      
      // Validasi kendaraanId untuk kupon RANJEN
      if (kendaraanId == null || kendaraanId <= 0) {
        throw Exception(
          'Kupon RANJEN memerlukan data Kendaraan yang valid. Kendaraan ID: $kendaraanId',
        );
      }
    }

    int jenisBbmId = 1;
    if (jenisBBM.isNotEmpty) {
      final jenisBBMLower = jenisBBM.toLowerCase();
      if (jenisBBMLower.contains('pertamina dex') ||
          jenisBBMLower.contains('dexlite') ||
          jenisBBMLower.contains('dex')) {
        jenisBbmId = 2;
      }
    }

    final kupon = KuponModel(
      kuponId: 0,
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
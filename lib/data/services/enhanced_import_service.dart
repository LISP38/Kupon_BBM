import '../models/kupon_model.dart';
import '../models/kendaraan_model.dart';
import '../datasources/excel_datasource.dart';
import '../datasources/database_datasource.dart';
import '../validators/enhanced_import_validator.dart';
import '../../domain/repositories/kupon_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

enum ImportType { validate_only, dry_run, validate_and_save }

class ImportResult {
  final bool success;
  final int successCount;
  final int errorCount;
  final int duplicateCount;
  final List<String> warnings;
  final List<String> errors;
  final Map<String, dynamic> metadata;

  ImportResult({
    required this.success,
    required this.successCount,
    required this.errorCount,
    required this.duplicateCount,
    this.warnings = const [],
    this.errors = const [],
    this.metadata = const {},
  });
}

class EnhancedImportService {
  final ExcelDatasource _excelDatasource;
  final KuponRepository _kuponRepository;
  final DatabaseDatasource _databaseDatasource;

  EnhancedImportService({
    required ExcelDatasource excelDatasource,
    required KuponRepository kuponRepository,
    required DatabaseDatasource databaseDatasource,
  }) : _excelDatasource = excelDatasource,
       _kuponRepository = kuponRepository,
       _databaseDatasource = databaseDatasource;

  // Method untuk mendapatkan preview data tanpa melakukan import
  Future<ExcelParseResult> getPreviewData({required String filePath}) async {
    final existingKupons = await _kuponRepository.getAllKupon();
    final existingKuponModels = existingKupons
        .map(
          (entity) => KuponModel(
            kuponId: entity.kuponId,
            nomorKupon: entity.nomorKupon,
            kendaraanId: entity.kendaraanId,
            jenisBbmId: entity.jenisBbmId,
            jenisKuponId: entity.jenisKuponId,
            bulanTerbit: entity.bulanTerbit,
            tahunTerbit: entity.tahunTerbit,
            tanggalMulai: entity.tanggalMulai,
            tanggalSampai: entity.tanggalSampai,
            kuotaAwal: entity.kuotaAwal,
            kuotaSisa: entity.kuotaSisa,
            satkerId: entity.satkerId,
            namaSatker: entity.namaSatker,
            status: entity.status,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt,
            isDeleted: entity.isDeleted,
          ),
        )
        .toList();

    return await _excelDatasource.parseExcelFile(filePath, existingKuponModels);
  }

  Future<ImportResult> performImport({
    required String filePath,
    required ImportType importType,
    int? expectedMonth,
    int? expectedYear,
  }) async {
    try {
      final existingKupons = await _kuponRepository.getAllKupon();
      final existingKuponModels = existingKupons
          .map(
            (entity) => KuponModel(
              kuponId: entity.kuponId,
              nomorKupon: entity.nomorKupon,
              kendaraanId: entity.kendaraanId,
              jenisBbmId: entity.jenisBbmId,
              jenisKuponId: entity.jenisKuponId,
              bulanTerbit: entity.bulanTerbit,
              tahunTerbit: entity.tahunTerbit,
              tanggalMulai: entity.tanggalMulai,
              tanggalSampai: entity.tanggalSampai,
              kuotaAwal: entity.kuotaAwal,
              kuotaSisa: entity.kuotaSisa,
              satkerId: entity.satkerId,
              namaSatker: entity.namaSatker,
              status: entity.status,
              createdAt: entity.createdAt,
              updatedAt: entity.updatedAt,
              isDeleted: entity.isDeleted,
            ),
          )
          .toList();

      final parseResult = await _excelDatasource.parseExcelFile(
        filePath,
        existingKuponModels,
      );

      final newKupons = parseResult.kupons;
      final newKendaraans = parseResult.newKendaraans;
      final duplicateKupons = parseResult.duplicateKupons;
      final duplicateCount = duplicateKupons.length;

      // Validate only NEW kupons (duplicates already separated)
      final validationResult = EnhancedImportValidator.validateImportPeriod(
        kupons: newKupons,
        expectedMonth: expectedMonth,
        expectedYear: expectedYear,
      );

      // Also validate internal duplicates in new kupons
      final internalDuplicateResult =
          EnhancedImportValidator.validateInternalDuplicates(newKupons);

      // Combine validation results
      final allErrors = <String>[];
      final allWarnings = <String>[];
      final allMetadata = <String, dynamic>{};

      allErrors.addAll(validationResult.errors);
      allErrors.addAll(internalDuplicateResult.errors);
      allWarnings.addAll(validationResult.warnings);
      allWarnings.addAll(internalDuplicateResult.warnings);
      allMetadata.addAll(validationResult.metadata);
      allMetadata.addAll(internalDuplicateResult.metadata);

      allMetadata['duplicate_count'] = duplicateCount;
      allMetadata['new_count'] = newKupons.length;

      // If validation fails or validate-only mode, return results
      if (allErrors.isNotEmpty || importType == ImportType.validate_only) {
        return ImportResult(
          success: importType == ImportType.validate_only,
          successCount: 0,
          errorCount: allErrors.length,
          duplicateCount: duplicateCount,
          warnings: allWarnings,
          errors: allErrors,
          metadata: allMetadata,
        );
      }

      // Process import
      final result = await _performAppendImport(
        newKupons: newKupons,
        newKendaraans: newKendaraans,
      );

      return ImportResult(
        success: result['error'] == 0,
        successCount: result['success'] ?? 0,
        errorCount: result['error'] ?? 0,
        duplicateCount: duplicateCount,
        warnings: allWarnings,
        errors: allErrors,
        metadata: allMetadata,
      );
    } catch (e) {
      return ImportResult(
        success: false,
        successCount: 0,
        errorCount: 1,
        duplicateCount: 0,
        errors: ['Failed to process import: $e'],
      );
    }
  }

  Future<Map<String, int>> _performAppendImport({
    required List<KuponModel> newKupons,
    required List<KendaraanModel> newKendaraans,
  }) async {
    int successCount = 0;
    int errorCount = 0;
    List<String> errorMessages = [];

    final db = await _databaseDatasource.database;
    final Map<String, int> kendaraanIdMap = {};

    print('Processing ${newKendaraans.length} kendaraans...');
    for (final kendaraan in newKendaraans) {
      final key =
          '${kendaraan.satkerId}_${kendaraan.jenisRanmor}_${kendaraan.noPolKode}_${kendaraan.noPolNomor}';

      // Cek apakah kendaraan dengan kunci ini sudah diproses sebelumnya (menghindari duplikat internal kendaraan)
      if (kendaraanIdMap.containsKey(key)) {
        print('Skipping duplicate kendaraan key: $key');
        continue;
      }

      try {
        // Cek apakah kendaraan sudah ada di database
        final existingResult = await db.query(
          'dim_kendaraan',
          where:
              'satker_id = ? AND jenis_ranmor = ? AND no_pol_kode = ? AND no_pol_nomor = ?',
          whereArgs: [
            kendaraan.satkerId,
            kendaraan.jenisRanmor,
            kendaraan.noPolKode,
            kendaraan.noPolNomor,
          ],
        );

        int kendaraanId;
        if (existingResult.isNotEmpty) {
          kendaraanId = existingResult.first['kendaraan_id'] as int;
          print('Found existing kendaraan with ID: $kendaraanId for key: $key');
        } else {
          // Insert kendaraan baru
          kendaraanId = await db.insert(
            'dim_kendaraan',
            kendaraan.toMap(),
            conflictAlgorithm: ConflictAlgorithm
                .replace, // Atau ConflictAlgorithm.abort jika ingin gagal saat duplikat
          );
          print('Inserted new kendaraan with ID: $kendaraanId for key: $key');
        }

        // Simpan mapping
        kendaraanIdMap[key] = kendaraanId;
      } catch (e) {
        print('ERROR processing kendaraan $key: $e');
        errorCount++;
        errorMessages.add('Failed to insert/update kendaraan $key: $e');
        // Lanjutkan ke kendaraan berikutnya
      }
    }

    // Proses kupon Ranjen dan Dukungan
    print('Processing ${newKupons.length} kupons...');
    for (final kupon in newKupons) {
      try {
        int? kendaraanId = null;

        if (kupon.jenisKuponId == 1) {
          // Ranjen
          // Alternatif: Coba temukan kendaraan model yang sesuai dari newKendaraans berdasarkan satker
          // Kita gunakan informasi yang diparsing dari Excel row untuk membuat kunci pencocokan
          // Misalnya, jika kupon Ranjen memiliki kendaraanId null, kita cari dari newKendaraans berdasarkan satker
          // Jika kupon Ranjen memiliki kendaraanId (karena _parseRow berhasil membuatnya), kita gunakan itu
          if (kupon.kendaraanId != null) {
            kendaraanId = kupon.kendaraanId;
            print(
              'Using kendaraanId from KuponModel for Ranjen ${kupon.nomorKupon}: ${kendaraanId}',
            );
          } else {
            // Jika kendaraanId null, coba cari di map berdasarkan kombinasi lain (ini bisa kompleks)
            // Lebih baik memastikan _parseRow selalu menghasilkan kendaraanId untuk Ranjen
            // Jika tidak, berarti data kendaraan tidak ditemukan/valid
            print(
              'ERROR: Ranjen ${kupon.nomorKupon} has null kendaraanId and no matching kendaraan found in newKendaraans map.',
            );
            errorCount++;
            errorMessages.add(
              'Ranjen ${kupon.nomorKupon} (${kupon.namaSatker}) failed: Kendaraan not found or invalid.',
            );
            continue; // Lanjutkan ke kupon berikutnya
          }

          // Validasi apakah kendaraanId ditemukan di map (jika pencocokan manual dilakukan)
          // if (kendaraanId == null || kendaraanId == 0) {
          //    print('ERROR: Ranjen ${kupon.nomorKupon} has null kendaraanId after mapping.');
          //    errorCount++;
          //    errorMessages.add('Ranjen ${kupon.nomorKupon} (${kupon.namaSatker}) failed: Kendaraan not found in map.');
          //    continue; // Lanjutkan ke kupon berikutnya
          // }
        } else if (kupon.jenisKuponId == 2) {
          // Dukungan
          // Untuk non-CADANGAN, cari kendaraan_id dari kupon Ranjen terkait di database
          if (kupon.namaSatker.toUpperCase() != 'CADANGAN') {
            final ranjenResult = await db.query(
              'fact_kupon',
              where: '''
                satker_id = ? AND 
                jenis_kupon_id = 1 AND 
                bulan_terbit = ? AND 
                tahun_terbit = ?
              ''',
              whereArgs: [kupon.satkerId, kupon.bulanTerbit, kupon.tahunTerbit],
              limit: 1, // Ambil satu saja jika ada
            );

            if (ranjenResult.isNotEmpty) {
              kendaraanId = ranjenResult.first['kendaraan_id'] as int?;
              print(
                'Found RANJEN with kendaraan_id: $kendaraanId for DUKUNGAN ${kupon.nomorKupon}',
              );
            } else {
              print(
                'No matching RANJEN found in DB for DUKUNGAN ${kupon.nomorKupon} (Satker: ${kupon.namaSatker}, Month: ${kupon.bulanTerbit}, Year: ${kupon.tahunTerbit})',
              );
              // Untuk DUKUNGAN non-CADANGAN, jika RANJEN tidak ditemukan, ini adalah error
              errorCount++;
              errorMessages.add(
                'Dukungan ${kupon.nomorKupon} (${kupon.namaSatker}) failed: No matching Ranjen found in database.',
              );
              continue; // Lanjutkan ke kupon berikutnya
            }
          } else {
            // Untuk CADANGAN, kendaraan_id tetap null
            print(
              'Processing CADANGAN DUKUNGAN ${kupon.nomorKupon}, kendaraan_id will be null.',
            );
          }
        }

        // Sekarang coba insert kupon
        final updatedKupon = kupon.copyWith(kendaraanId: kendaraanId);

        await db.insert(
          'fact_kupon',
          updatedKupon.toMap(),
          conflictAlgorithm: ConflictAlgorithm
              .replace, // Atau ConflictAlgorithm.abort jika ingin gagal saat duplikat
        );

        successCount++;
        print(
          '✅ Successfully inserted kupon: ${kupon.nomorKupon} (${kupon.jenisKuponId == 1 ? "RANJEN" : "DUKUNGAN"})',
        );
      } catch (e) {
        errorCount++;
        errorMessages.add('ERROR processing kupon ${kupon.nomorKupon}: $e');
        print('❌ ERROR processing kupon ${kupon.nomorKupon}: $e');
      }
    }

    print(
      'Import completed with $successCount successful and $errorCount failed kupons',
    );
    if (errorMessages.isNotEmpty) {
      print('Error messages:');
      errorMessages.forEach((msg) => print(' - $msg'));
    }

    return {'success': successCount, 'error': errorCount};
  }
}

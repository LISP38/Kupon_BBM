import 'dart:convert';
import '../models/kupon_model.dart';
import '../models/kendaraan_model.dart';
import '../models/import_history_model.dart';
import '../datasources/excel_datasource.dart';
import '../datasources/database_datasource.dart';
import '../validators/enhanced_import_validator.dart';
import '../../domain/repositories/kupon_repository.dart';
import '../../domain/repositories/import_history_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

enum ImportType { append, validate_only }

class ImportResult {
  final bool success;
  final int sessionId;
  final int successCount;
  final int errorCount;
  final int duplicateCount;
  final List<String> warnings;
  final List<String> errors;
  final Map<String, dynamic> metadata;

  ImportResult({
    required this.success,
    required this.sessionId,
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
  final ImportHistoryRepository _importHistoryRepository;
  final DatabaseDatasource _databaseDatasource;

  EnhancedImportService({
    required ExcelDatasource excelDatasource,
    required KuponRepository kuponRepository,
    required ImportHistoryRepository importHistoryRepository,
    required DatabaseDatasource databaseDatasource,
  }) : _excelDatasource = excelDatasource,
       _kuponRepository = kuponRepository,
       _importHistoryRepository = importHistoryRepository,
       _databaseDatasource = databaseDatasource;

  // Method untuk mendapatkan preview data tanpa melakukan import
  Future<ExcelParseResult> getPreviewData({required String filePath}) async {
    // Get existing kupons for validation
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

    // Parse Excel file dengan existing data untuk deteksi duplikat
    return await _excelDatasource.parseExcelFile(filePath, existingKuponModels);
  }

  Future<ImportResult> performImport({
    required String filePath,
    required ImportType importType,
    int? expectedMonth,
    int? expectedYear,
  }) async {
    final fileName = filePath.split('/').last;
    final importDate = DateTime.now();
    final expectedPeriod = (expectedMonth != null && expectedYear != null)
        ? '$expectedMonth/$expectedYear'
        : null;

    // Step 1: Parse Excel file
    print('DEBUG: Starting import for file: $fileName');

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

    ExcelParseResult parseResult;
    try {
      parseResult = await _excelDatasource.parseExcelFile(
        filePath,
        existingKuponModels,
      );
    } catch (e) {
      // Create failed session record
      final sessionId = await _importHistoryRepository.createImportSession(
        fileName: fileName,
        importType: importType.name,
        importDate: importDate,
        expectedPeriod: expectedPeriod,
        totalKupons: 0,
      );

      await _importHistoryRepository.updateImportSession(
        sessionId: sessionId,
        status: 'FAILED',
        errorCount: 1,
        errorMessage: 'Failed to parse Excel file: $e',
      );

      return ImportResult(
        success: false,
        sessionId: sessionId,
        successCount: 0,
        errorCount: 1,
        duplicateCount: 0,
        errors: ['Failed to parse Excel file: $e'],
      );
    }

    final newKupons = parseResult.kupons;
    final newKendaraans = parseResult.newKendaraans;
    final duplicateKupons = parseResult.duplicateKupons;
    final duplicateCount = duplicateKupons.length;
    final totalKupons = newKupons.length + duplicateCount;

    // Step 2: Create import session
    final sessionId = await _importHistoryRepository.createImportSession(
      fileName: fileName,
      importType: importType.name,
      importDate: importDate,
      expectedPeriod: expectedPeriod,
      totalKupons: totalKupons,
    );

    try {
      // Step 3: Validate only NEW kupons (duplicates already separated)
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

      // Add duplicate information
      allMetadata['duplicate_count'] = duplicateCount;
      allMetadata['new_count'] = newKupons.length;

      // Log validation results
      for (final error in allErrors) {
        await _importHistoryRepository.logImportDetail(
          sessionId: sessionId,
          kuponData: 'VALIDATION_ERROR',
          status: 'ERROR',
          errorMessage: error,
          action: 'VALIDATE',
        );
      }

      for (final warning in allWarnings) {
        await _importHistoryRepository.logImportDetail(
          sessionId: sessionId,
          kuponData: 'VALIDATION_WARNING',
          status: 'WARNING',
          errorMessage: warning,
          action: 'VALIDATE',
        );
      }

      // Log duplicate information
      if (duplicateCount > 0) {
        await _importHistoryRepository.logImportDetail(
          sessionId: sessionId,
          kuponData: 'DUPLICATE_INFO',
          status: 'INFO',
          errorMessage:
              '$duplicateCount kupon duplikat ditemukan dan akan dilewati',
          action: 'SKIP_DUPLICATE',
        );
      }

      // If validation fails or validate-only mode, return results
      if (allErrors.isNotEmpty || importType == ImportType.validate_only) {
        await _importHistoryRepository.updateImportSession(
          sessionId: sessionId,
          status: importType == ImportType.validate_only
              ? 'VALIDATED'
              : 'VALIDATION_FAILED',
          errorCount: allErrors.length,
          duplicateCount: duplicateCount,
          metadata: allMetadata,
        );

        return ImportResult(
          success: importType == ImportType.validate_only,
          sessionId: sessionId,
          successCount: 0,
          errorCount: allErrors.length,
          duplicateCount: duplicateCount,
          warnings: allWarnings,
          errors: allErrors,
          metadata: allMetadata,
        );
      }

      // Step 5: Process import based on type
      int successCount = 0;
      int errorCount = 0;

      // Handle append import (only mode available now)
      {
        final result = await _performAppendImport(
          sessionId: sessionId,
          newKupons: newKupons,
          newKendaraans: newKendaraans,
        );
        successCount = result['success'] ?? 0;
        errorCount = result['error'] ?? 0;
      }

      // Step 6: Update session with final results
      await _importHistoryRepository.updateImportSession(
        sessionId: sessionId,
        status: errorCount > 0 ? 'COMPLETED_WITH_ERRORS' : 'SUCCESS',
        successCount: successCount,
        errorCount: errorCount,
        duplicateCount: duplicateCount,
        metadata: allMetadata,
      );

      return ImportResult(
        success: errorCount == 0,
        sessionId: sessionId,
        successCount: successCount,
        errorCount: errorCount,
        duplicateCount: duplicateCount,
        warnings: allWarnings,
        errors: allErrors,
        metadata: allMetadata,
      );
    } catch (e) {
      // Handle unexpected errors
      await _importHistoryRepository.updateImportSession(
        sessionId: sessionId,
        status: 'FAILED',
        errorCount: 1,
        errorMessage: 'Unexpected error: $e',
      );

      await _importHistoryRepository.logImportDetail(
        sessionId: sessionId,
        kuponData: 'SYSTEM_ERROR',
        status: 'ERROR',
        errorMessage: 'Unexpected error: $e',
        action: 'SYSTEM',
      );

      return ImportResult(
        success: false,
        sessionId: sessionId,
        successCount: 0,
        errorCount: 1,
        duplicateCount: 0,
        errors: ['Unexpected error occurred: $e'],
      );
    }
  }

  Future<Map<String, int>> _performAppendImport({
    required int sessionId,
    required List<KuponModel> newKupons,
    required List<KendaraanModel> newKendaraans,
  }) async {
    int successCount = 0;
    int errorCount = 0;

    // Use a single database transaction to ensure atomicity
    final db = await _databaseDatasource.database;
    final Map<String, int> kendaraanIdMap = {};

    try {
      await db.transaction((txn) async {
        // Step 1: Process kendaraan records first to ensure they exist before inserting kupons
        print(
          'Processing ${newKendaraans.length} kendaraans...',
        ); // Process all unique kendaraans
        for (final kendaraan in newKendaraans) {
          final key = '${kendaraan.noPolKode}${kendaraan.noPolNomor}';
          print('Processing kendaraan: $key');

          // Skip if already processed
          if (kendaraanIdMap.containsKey(key)) {
            print('Skipping already processed kendaraan: $key');
            continue;
          }

          try {
            // Check if kendaraan already exists within transaction
            final existingResult = await txn.query(
              'dim_kendaraan',
              where: 'no_pol_kode = ? AND no_pol_nomor = ?',
              whereArgs: [kendaraan.noPolKode, kendaraan.noPolNomor],
            );

            int kendaraanId;
            if (existingResult.isNotEmpty) {
              // Use existing kendaraan ID
              kendaraanId = existingResult.first['kendaraan_id'] as int;
              print(
                'Found existing kendaraan with ID: $kendaraanId for key: $key',
              );
            } else {
              // Insert new kendaraan within transaction
              kendaraanId = await txn.insert(
                'dim_kendaraan',
                kendaraan.toMap(),
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
              print(
                'Inserted new kendaraan with ID: $kendaraanId for key: $key',
              );

              // Verify the insertion was successful
              final verifyResult = await txn.query(
                'dim_kendaraan',
                where: 'kendaraan_id = ?',
                whereArgs: [kendaraanId],
              );
              if (verifyResult.isEmpty) {
                throw Exception(
                  'Failed to verify kendaraan insertion with ID: $kendaraanId',
                );
              }
              print('Verified kendaraan insertion: ${verifyResult.first}');
            }

            // Map kendaraan key to ID for kupon processing
            kendaraanIdMap[key] = kendaraanId;
            print('Mapped $key -> ID: $kendaraanId');
          } catch (e) {
            print('ERROR processing kendaraan $key: $e');
            throw e; // Re-throw to abort transaction
          }
        }

        print('Kendaraan processing complete. ID Map: $kendaraanIdMap');

        // Step 2: Process kupon records with updated kendaraan IDs within the same transaction
        print('Processing ${newKupons.length} kupons...');
        print('Available kendaraans: ${newKendaraans.length}');
        print('KendaraanIdMap has ${kendaraanIdMap.length} entries');

        for (int i = 0; i < newKupons.length; i++) {
          final kupon = newKupons[i];
          print('Processing kupon $i: ${kupon.nomorKupon}');

          try {
            // Handle kupon DUKUNGAN (jenisKuponId == 2) yang tidak memiliki kendaraan
            if (kupon.jenisKuponId == 2) {
              // Kupon DUKUNGAN - cari kendaraan dari kupon RANJEN yang sesuai
              print('Processing DUKUNGAN kupon: ${kupon.nomorKupon}');

              // Cari kupon RANJEN di database untuk satker dan periode yang sama
              final ranjenKupons = await txn.query(
                'fact_kupon',
                where: '''
                  satker_id = ? AND 
                  jenis_kupon_id = 1 AND 
                  bulan_terbit = ? AND 
                  tahun_terbit = ?
                ''',
                whereArgs: [
                  kupon.satkerId,
                  kupon.bulanTerbit,
                  kupon.tahunTerbit,
                ],
              );

              int? kendaraanId;
              if (ranjenKupons.isNotEmpty) {
                kendaraanId = ranjenKupons.first['kendaraan_id'] as int?;
                print('Found RANJEN kupon with kendaraan_id: $kendaraanId');
              } else {
                print(
                  'No RANJEN kupon found for DUKUNGAN - using null kendaraan_id',
                );
              }

              // Insert kupon DUKUNGAN dengan kendaraan_id dari RANJEN atau null
              final dukunganKupon = kupon.copyWith(kendaraanId: kendaraanId);

              await txn.insert(
                'fact_kupon',
                dukunganKupon.toMap(),
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
              successCount++;
            } else {
              // Kupon RANJEN - cari kendaraan yang sesuai berdasarkan satker dan periode
              print('Processing RANJEN kupon: ${kupon.nomorKupon}');

              // Cari kendaraan yang sesuai untuk kupon RANJEN berdasarkan satkerId dan periode
              KendaraanModel? correspondingKendaraan;
              for (final kendaraan in newKendaraans) {
                if (kendaraan.satkerId == kupon.satkerId) {
                  correspondingKendaraan = kendaraan;
                  break;
                }
              }

              if (correspondingKendaraan != null) {
                final key =
                    '${correspondingKendaraan.noPolKode}${correspondingKendaraan.noPolNomor}';
                print(
                  'RANJEN kupon ${kupon.nomorKupon} corresponds to kendaraan: $key',
                );
                final kendaraanId = kendaraanIdMap[key];
                print(
                  'Looking up kendaraan ID for key: $key, found: $kendaraanId',
                );

                if (kendaraanId != null && kendaraanId != 0) {
                  // Update kupon with correct kendaraan ID and insert within transaction
                  final updatedKupon = kupon.copyWith(kendaraanId: kendaraanId);

                  print('Original kupon kendaraan_id: ${kupon.kendaraanId}');
                  print(
                    'Updated kupon kendaraan_id: ${updatedKupon.kendaraanId}',
                  );
                  print(
                    'Inserting kupon ${kupon.nomorKupon} with kendaraanId: $kendaraanId',
                  );

                  await txn.insert(
                    'fact_kupon',
                    updatedKupon.toMap(),
                    conflictAlgorithm: ConflictAlgorithm.replace,
                  );
                  successCount++;
                } else {
                  print('ERROR: Kendaraan ID not found or is 0 for key: $key');
                  print('kendaraanId value: $kendaraanId');
                  print(
                    'Available keys in map: ${kendaraanIdMap.keys.toList()}',
                  );
                  print('Full kendaraanIdMap: $kendaraanIdMap');

                  throw Exception(
                    'Kendaraan ID not found for corresponding kendaraan: $key',
                  );
                }
              } else {
                // Kupon RANJEN tanpa kendaraan yang sesuai - ini error
                throw Exception(
                  'RANJEN kupon ${kupon.nomorKupon} (satker: ${kupon.satkerId}) must have corresponding kendaraan',
                );
              }
            }
          } catch (e) {
            errorCount++;
            print('ERROR processing kupon ${kupon.nomorKupon}: $e');
            throw e; // Re-throw to abort transaction
          }
        }
      });

      // Transaction completed successfully
      print('Transaction completed successfully. Logging import history...');

      // Log successful operations after transaction
      for (final entry in kendaraanIdMap.entries) {
        final key = entry.key;

        // Find corresponding kendaraan for logging
        final kendaraan = newKendaraans.firstWhere(
          (k) => '${k.noPolKode}${k.noPolNomor}' == key,
          orElse: () => throw Exception('Kendaraan not found for key: $key'),
        );

        await _importHistoryRepository.logImportDetail(
          sessionId: sessionId,
          kuponData: jsonEncode(kendaraan.toMap()),
          status: 'SUCCESS',
          action: 'INSERT_KENDARAAN',
        );
      }

      // Log successful kupon operations
      for (final kupon in newKupons) {
        if (kupon.jenisKuponId == 1) {
          // Kupon RANJEN - cari kendaraan yang sesuai
          KendaraanModel? correspondingKendaraan;
          for (final k in newKendaraans) {
            if (k.satkerId == kupon.satkerId) {
              correspondingKendaraan = k;
              break;
            }
          }

          if (correspondingKendaraan != null) {
            final key =
                '${correspondingKendaraan.noPolKode}${correspondingKendaraan.noPolNomor}';
            final kendaraanId = kendaraanIdMap[key];

            if (kendaraanId != null) {
              final updatedKupon = kupon.copyWith(kendaraanId: kendaraanId);

              await _importHistoryRepository.logImportDetail(
                sessionId: sessionId,
                kuponData: jsonEncode(updatedKupon.toMap()),
                status: 'SUCCESS',
                action: 'INSERT',
              );
            }
          }
        } else if (kupon.jenisKuponId == 2) {
          // Kupon DUKUNGAN - log tanpa kendaraan
          await _importHistoryRepository.logImportDetail(
            sessionId: sessionId,
            kuponData: jsonEncode(kupon.toMap()),
            status: 'SUCCESS',
            action: 'INSERT',
          );
        }
      }
    } catch (e) {
      print('Transaction failed: $e');

      // Log error details
      await _importHistoryRepository.logImportDetail(
        sessionId: sessionId,
        kuponData: jsonEncode({'error': e.toString()}),
        status: 'ERROR',
        errorMessage: 'Transaction failed: $e',
        action: 'TRANSACTION_ERROR',
      );

      throw e;
    }

    return {'success': successCount, 'error': errorCount};
  }

  // Helper methods for import history management
  Future<List<ImportHistoryModel>> getImportHistory() async {
    return await _importHistoryRepository.getImportHistory(limit: 50);
  }

  Future<ImportHistoryModel?> getImportSession(int sessionId) async {
    return await _importHistoryRepository.getImportSession(sessionId);
  }

  Future<List<ImportDetailModel>> getImportDetails(int sessionId) async {
    return await _importHistoryRepository.getImportDetails(sessionId);
  }

  Future<void> deleteImportSession(int sessionId) async {
    await _importHistoryRepository.deleteImportSession(sessionId);
  }

  Future<List<ImportHistoryModel>> checkConflictingImports({
    required int month,
    required int year,
  }) async {
    return await _importHistoryRepository.getConflictingSessions(
      month: month,
      year: year,
    );
  }
}

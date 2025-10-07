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

    final db = await _databaseDatasource.database;
    final Map<String, int> kendaraanIdMap = {};

    // SOLUSI 1: Process kendaraan terlebih dahulu di luar transaction
    print('Processing ${newKendaraans.length} kendaraans...');
    for (final kendaraan in newKendaraans) {
      final key = '${kendaraan.noPolKode}${kendaraan.noPolNomor}';

      if (kendaraanIdMap.containsKey(key)) {
        continue; // Skip if already processed
      }

      try {
        // Check if kendaraan already exists
        final existingResult = await db.query(
          'dim_kendaraan',
          where: 'no_pol_kode = ? AND no_pol_nomor = ?',
          whereArgs: [kendaraan.noPolKode, kendaraan.noPolNomor],
        );

        int kendaraanId;
        if (existingResult.isNotEmpty) {
          kendaraanId = existingResult.first['kendaraan_id'] as int;
          print('Found existing kendaraan with ID: $kendaraanId for key: $key');
        } else {
          kendaraanId = await db.insert(
            'dim_kendaraan',
            kendaraan.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          print('Inserted new kendaraan with ID: $kendaraanId for key: $key');
        }

        kendaraanIdMap[key] = kendaraanId;
      } catch (e) {
        print('ERROR processing kendaraan $key: $e');
        // Continue processing other kendaraan instead of failing completely
        await _importHistoryRepository.logImportDetail(
          sessionId: sessionId,
          kuponData: 'KENDARAAN_ERROR: $key',
          status: 'ERROR',
          errorMessage: 'Failed to process kendaraan: $e',
          action: 'INSERT_KENDARAAN_FAILED',
        );
      }
    }

    // SOLUSI 2: Separate RANJEN and DUKUNGAN processing with individual transactions
    // Process RANJEN first to establish kendaraan dependencies
    final ranjenKupons = newKupons.where((k) => k.jenisKuponId == 1).toList();
    final dukunganKupons = newKupons.where((k) => k.jenisKuponId == 2).toList();

    print('Processing ${ranjenKupons.length} RANJEN kupons...');
    for (final kupon in ranjenKupons) {
      try {
        // Find corresponding kendaraan
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
          final kendaraanId = kendaraanIdMap[key];

          if (kendaraanId != null && kendaraanId != 0) {
            final updatedKupon = kupon.copyWith(kendaraanId: kendaraanId);

            await db.insert(
              'fact_kupon',
              updatedKupon.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );

            successCount++;
            print('✅ Successfully inserted RANJEN kupon: ${kupon.nomorKupon}');

            // Log successful operation
            await _importHistoryRepository.logImportDetail(
              sessionId: sessionId,
              kuponData: jsonEncode(updatedKupon.toMap()),
              status: 'SUCCESS',
              action: 'INSERT_RANJEN',
            );
          } else {
            errorCount++;
            final errorMsg = 'Kendaraan ID not found for key: $key';
            print(
              '❌ ERROR processing RANJEN kupon ${kupon.nomorKupon}: $errorMsg',
            );

            await _importHistoryRepository.logImportDetail(
              sessionId: sessionId,
              kuponData: jsonEncode(kupon.toMap()),
              status: 'ERROR',
              errorMessage: errorMsg,
              action: 'INSERT_RANJEN_FAILED',
            );
          }
        } else {
          errorCount++;
          final errorMsg =
              'No corresponding kendaraan found for satker: ${kupon.satkerId}';
          print(
            '❌ ERROR processing RANJEN kupon ${kupon.nomorKupon}: $errorMsg',
          );

          await _importHistoryRepository.logImportDetail(
            sessionId: sessionId,
            kuponData: jsonEncode(kupon.toMap()),
            status: 'ERROR',
            errorMessage: errorMsg,
            action: 'INSERT_RANJEN_FAILED',
          );
        }
      } catch (e) {
        errorCount++;
        print('❌ ERROR processing RANJEN kupon ${kupon.nomorKupon}: $e');

        await _importHistoryRepository.logImportDetail(
          sessionId: sessionId,
          kuponData: jsonEncode(kupon.toMap()),
          status: 'ERROR',
          errorMessage: 'Failed to insert RANJEN kupon: $e',
          action: 'INSERT_RANJEN_FAILED',
        );
      }
    }

    print('Processing ${dukunganKupons.length} DUKUNGAN kupons...');
    for (final kupon in dukunganKupons) {
      try {
        int? kendaraanId;

        // SOLUSI 3: Improved DUKUNGAN handling - check both database and current batch
        if (kupon.namaSatker.toUpperCase() != 'CADANGAN') {
          // For non-CADANGAN DUKUNGAN, find kendaraan from RANJEN
          final ranjenKupons = await db.query(
            'fact_kupon',
            where: '''
              satker_id = ? AND 
              jenis_kupon_id = 1 AND 
              bulan_terbit = ? AND 
              tahun_terbit = ?
            ''',
            whereArgs: [kupon.satkerId, kupon.bulanTerbit, kupon.tahunTerbit],
          );

          if (ranjenKupons.isNotEmpty) {
            kendaraanId = ranjenKupons.first['kendaraan_id'] as int?;
            print(
              'Found RANJEN kupon with kendaraan_id: $kendaraanId for DUKUNGAN ${kupon.nomorKupon}',
            );
          } else {
            print(
              'No RANJEN kupon found for DUKUNGAN ${kupon.nomorKupon} - using null kendaraan_id',
            );
          }
        }

        final dukunganKupon = kupon.copyWith(kendaraanId: kendaraanId);

        await db.insert(
          'fact_kupon',
          dukunganKupon.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        successCount++;
        print('✅ Successfully inserted DUKUNGAN kupon: ${kupon.nomorKupon}');

        // Log successful operation
        await _importHistoryRepository.logImportDetail(
          sessionId: sessionId,
          kuponData: jsonEncode(dukunganKupon.toMap()),
          status: 'SUCCESS',
          action: 'INSERT_DUKUNGAN',
        );
      } catch (e) {
        errorCount++;
        print('❌ ERROR processing DUKUNGAN kupon ${kupon.nomorKupon}: $e');

        await _importHistoryRepository.logImportDetail(
          sessionId: sessionId,
          kuponData: jsonEncode(kupon.toMap()),
          status: 'ERROR',
          errorMessage: 'Failed to insert DUKUNGAN kupon: $e',
          action: 'INSERT_DUKUNGAN_FAILED',
        );
      }
    }

    // Log successful kendaraan operations
    for (final entry in kendaraanIdMap.entries) {
      final key = entry.key;
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

    print(
      'Import completed with $successCount successful and $errorCount failed kupons',
    );

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

  // SOLUSI: Method untuk analisis error import
  Future<Map<String, dynamic>> analyzeImportErrors(int sessionId) async {
    final session = await getImportSession(sessionId);
    final details = await getImportDetails(sessionId);

    if (session == null) {
      return {'error': 'Session not found'};
    }

    final errorDetails = details.where((d) => d.status == 'ERROR').toList();

    final errorCategories = <String, int>{};
    final errorMessages = <String>[];

    for (final error in errorDetails) {
      final message = error.errorMessage ?? 'Unknown error';
      errorMessages.add(message);

      // Kategorikan error
      if (message.contains('kendaraan')) {
        errorCategories['Kendaraan Issues'] =
            (errorCategories['Kendaraan Issues'] ?? 0) + 1;
      } else if (message.contains('duplikat') ||
          message.contains('sudah ada')) {
        errorCategories['Duplicate Issues'] =
            (errorCategories['Duplicate Issues'] ?? 0) + 1;
      } else if (message.contains('RANJEN') || message.contains('DUKUNGAN')) {
        errorCategories['Dependency Issues'] =
            (errorCategories['Dependency Issues'] ?? 0) + 1;
      } else if (message.contains('format') || message.contains('parsing')) {
        errorCategories['Format Issues'] =
            (errorCategories['Format Issues'] ?? 0) + 1;
      } else {
        errorCategories['Other Issues'] =
            (errorCategories['Other Issues'] ?? 0) + 1;
      }
    }

    return {
      'session_id': sessionId,
      'total_kupons': session.totalKupons,
      'success_count': session.successCount,
      'error_count': session.errorCount,
      'duplicate_count': session.duplicateCount,
      'error_categories': errorCategories,
      'error_messages': errorMessages,
      'success_rate': ((session.successCount / session.totalKupons) * 100)
          .toStringAsFixed(2),
      'recommendations': _generateRecommendations(
        errorCategories,
        errorMessages,
      ),
    };
  }

  List<String> _generateRecommendations(
    Map<String, int> errorCategories,
    List<String> errorMessages,
  ) {
    final recommendations = <String>[];

    if (errorCategories.containsKey('Kendaraan Issues')) {
      recommendations.add(
        'Periksa data kendaraan: pastikan No Pol dan Kode No Pol sudah benar',
      );
    }

    if (errorCategories.containsKey('Duplicate Issues')) {
      recommendations.add(
        'Hapus data duplikat dari file Excel sebelum import ulang',
      );
    }

    if (errorCategories.containsKey('Dependency Issues')) {
      recommendations.add(
        'Pastikan kupon RANJEN diletakkan sebelum kupon DUKUNGAN dalam file Excel',
      );
      recommendations.add(
        'Setiap kupon DUKUNGAN harus memiliki kupon RANJEN yang sesuai',
      );
    }

    if (errorCategories.containsKey('Format Issues')) {
      recommendations.add(
        'Periksa format file Excel: gunakan template yang disediakan',
      );
      recommendations.add(
        'Pastikan format tanggal, bulan (angka romawi), dan angka sudah benar',
      );
    }

    recommendations.add(
      'Gunakan fitur Preview sebelum melakukan import untuk melihat potential issues',
    );
    recommendations.add(
      'Import data dalam batch kecil jika file terlalu besar',
    );

    return recommendations;
  }
}

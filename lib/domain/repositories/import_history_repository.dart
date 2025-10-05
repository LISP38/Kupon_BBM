import '../../data/models/import_history_model.dart';

abstract class ImportHistoryRepository {
  Future<int> createImportSession({
    required String fileName,
    required String importType,
    required DateTime importDate,
    String? expectedPeriod,
    required int totalKupons,
  });

  Future<void> updateImportSession({
    required int sessionId,
    required String status,
    int? successCount,
    int? errorCount,
    int? duplicateCount,
    String? errorMessage,
    Map<String, dynamic>? metadata,
  });

  Future<void> logImportDetail({
    required int sessionId,
    required String kuponData,
    required String status,
    String? errorMessage,
    String? action,
  });

  Future<List<ImportHistoryModel>> getImportHistory({
    int? limit,
    String? status,
    DateTime? fromDate,
    DateTime? toDate,
  });

  Future<ImportHistoryModel?> getImportSession(int sessionId);

  Future<List<ImportDetailModel>> getImportDetails(int sessionId);

  Future<void> deleteImportSession(int sessionId);

  Future<List<ImportHistoryModel>> getConflictingSessions({
    required int month,
    required int year,
  });
}

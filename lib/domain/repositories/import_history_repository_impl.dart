import 'dart:convert';
import '../../data/datasources/database_datasource.dart';
import '../../data/models/import_history_model.dart';
import '../repositories/import_history_repository.dart';

class ImportHistoryRepositoryImpl implements ImportHistoryRepository {
  final DatabaseDatasource _databaseDatasource;

  ImportHistoryRepositoryImpl(this._databaseDatasource);

  @override
  Future<int> createImportSession({
    required String fileName,
    required String importType,
    required DateTime importDate,
    String? expectedPeriod,
    required int totalKupons,
  }) async {
    final db = await _databaseDatasource.database;

    final sessionData = {
      'file_name': fileName,
      'import_type': importType,
      'import_date': importDate.toIso8601String(),
      'expected_period': expectedPeriod,
      'total_kupons': totalKupons,
      'status': 'PROCESSING',
      'success_count': 0,
      'error_count': 0,
      'duplicate_count': 0,
      'created_at': DateTime.now().toIso8601String(),
    };

    return await db.insert('import_history', sessionData);
  }

  @override
  Future<void> updateImportSession({
    required int sessionId,
    required String status,
    int? successCount,
    int? errorCount,
    int? duplicateCount,
    String? errorMessage,
    Map<String, dynamic>? metadata,
  }) async {
    final db = await _databaseDatasource.database;

    final updateData = <String, dynamic>{
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (successCount != null) updateData['success_count'] = successCount;
    if (errorCount != null) updateData['error_count'] = errorCount;
    if (duplicateCount != null) updateData['duplicate_count'] = duplicateCount;
    if (errorMessage != null) updateData['error_message'] = errorMessage;
    if (metadata != null) updateData['metadata'] = jsonEncode(metadata);

    await db.update(
      'import_history',
      updateData,
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
  }

  @override
  Future<void> logImportDetail({
    required int sessionId,
    required String kuponData,
    required String status,
    String? errorMessage,
    String? action,
  }) async {
    final db = await _databaseDatasource.database;

    final detailData = {
      'session_id': sessionId,
      'kupon_data': kuponData,
      'status': status,
      'error_message': errorMessage,
      'action': action,
      'created_at': DateTime.now().toIso8601String(),
    };

    await db.insert('import_details', detailData);
  }

  @override
  Future<List<ImportHistoryModel>> getImportHistory({
    int? limit,
    String? status,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final db = await _databaseDatasource.database;

    String whereClause = '1=1';
    List<dynamic> whereArgs = [];

    if (status != null) {
      whereClause += ' AND status = ?';
      whereArgs.add(status);
    }

    if (fromDate != null) {
      whereClause += ' AND import_date >= ?';
      whereArgs.add(fromDate.toIso8601String());
    }

    if (toDate != null) {
      whereClause += ' AND import_date <= ?';
      whereArgs.add(toDate.toIso8601String());
    }

    String query =
        'SELECT * FROM import_history WHERE $whereClause ORDER BY import_date DESC';

    if (limit != null) {
      query += ' LIMIT $limit';
    }

    final List<Map<String, dynamic>> maps = await db.rawQuery(query, whereArgs);

    return List.generate(maps.length, (i) {
      return ImportHistoryModel.fromMap(maps[i]);
    });
  }

  @override
  Future<ImportHistoryModel?> getImportSession(int sessionId) async {
    final db = await _databaseDatasource.database;

    final List<Map<String, dynamic>> maps = await db.query(
      'import_history',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );

    if (maps.isNotEmpty) {
      return ImportHistoryModel.fromMap(maps.first);
    }
    return null;
  }

  @override
  Future<List<ImportDetailModel>> getImportDetails(int sessionId) async {
    final db = await _databaseDatasource.database;

    final List<Map<String, dynamic>> maps = await db.query(
      'import_details',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at ASC',
    );

    return List.generate(maps.length, (i) {
      return ImportDetailModel.fromMap(maps[i]);
    });
  }

  @override
  Future<void> deleteImportSession(int sessionId) async {
    final db = await _databaseDatasource.database;

    await db.transaction((txn) async {
      // Delete details first
      await txn.delete(
        'import_details',
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );

      // Then delete session
      await txn.delete(
        'import_history',
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );
    });
  }

  @override
  Future<List<ImportHistoryModel>> getConflictingSessions({
    required int month,
    required int year,
  }) async {
    final db = await _databaseDatasource.database;

    final expectedPeriod = '$month/$year';

    final List<Map<String, dynamic>> maps = await db.query(
      'import_history',
      where: 'expected_period = ? AND status = ?',
      whereArgs: [expectedPeriod, 'SUCCESS'],
      orderBy: 'import_date DESC',
    );

    return List.generate(maps.length, (i) {
      return ImportHistoryModel.fromMap(maps[i]);
    });
  }
}

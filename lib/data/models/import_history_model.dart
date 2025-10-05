import 'dart:convert';

class ImportHistoryModel {
  final int sessionId;
  final String fileName;
  final String importType;
  final String importDate;
  final String? expectedPeriod;
  final int totalKupons;
  final int successCount;
  final int errorCount;
  final int duplicateCount;
  final String status;
  final String? errorMessage;
  final Map<String, dynamic>? metadata;
  final String? createdAt;
  final String? updatedAt;

  ImportHistoryModel({
    required this.sessionId,
    required this.fileName,
    required this.importType,
    required this.importDate,
    this.expectedPeriod,
    required this.totalKupons,
    required this.successCount,
    required this.errorCount,
    required this.duplicateCount,
    required this.status,
    this.errorMessage,
    this.metadata,
    this.createdAt,
    this.updatedAt,
  });

  factory ImportHistoryModel.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic>? parsedMetadata;
    if (map['metadata'] != null && map['metadata'] is String) {
      try {
        parsedMetadata = jsonDecode(map['metadata']);
      } catch (e) {
        parsedMetadata = null;
      }
    }

    return ImportHistoryModel(
      sessionId: map['session_id'] as int,
      fileName: map['file_name'] as String,
      importType: map['import_type'] as String,
      importDate: map['import_date'] as String,
      expectedPeriod: map['expected_period'] as String?,
      totalKupons: map['total_kupons'] as int,
      successCount: map['success_count'] as int? ?? 0,
      errorCount: map['error_count'] as int? ?? 0,
      duplicateCount: map['duplicate_count'] as int? ?? 0,
      status: map['status'] as String,
      errorMessage: map['error_message'] as String?,
      metadata: parsedMetadata,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'session_id': sessionId,
      'file_name': fileName,
      'import_type': importType,
      'import_date': importDate,
      'expected_period': expectedPeriod,
      'total_kupons': totalKupons,
      'success_count': successCount,
      'error_count': errorCount,
      'duplicate_count': duplicateCount,
      'status': status,
      'error_message': errorMessage,
      'metadata': metadata != null ? jsonEncode(metadata) : null,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

class ImportDetailModel {
  final int detailId;
  final int sessionId;
  final String kuponData;
  final String status; // 'SUCCESS', 'FAILED', 'WARNING', 'ERROR', 'REPLACED'
  final String? errorMessage;
  final String?
  action; // 'INSERT', 'REPLACE', 'DELETE_EXISTING', 'VALIDATE', 'SYSTEM'
  final String? createdAt;

  ImportDetailModel({
    required this.detailId,
    required this.sessionId,
    required this.kuponData,
    required this.status,
    this.errorMessage,
    this.action,
    this.createdAt,
  });

  factory ImportDetailModel.fromMap(Map<String, dynamic> map) {
    return ImportDetailModel(
      detailId: map['detail_id'] as int,
      sessionId: map['session_id'] as int,
      kuponData: map['kupon_data'] as String,
      status: map['status'] as String,
      errorMessage: map['error_message'] as String?,
      action: map['action'] as String?,
      createdAt: map['created_at'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'detail_id': detailId,
      'session_id': sessionId,
      'kupon_data': kuponData,
      'status': status,
      'error_message': errorMessage,
      'action': action,
      'created_at': createdAt,
    };
  }
}

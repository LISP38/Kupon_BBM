import 'package:flutter/foundation.dart';
import '../../data/services/enhanced_import_service.dart';
import '../../data/models/import_history_model.dart';
import '../../data/datasources/excel_datasource.dart';

class EnhancedImportProvider with ChangeNotifier {
  final EnhancedImportService _importService;

  EnhancedImportProvider(this._importService);

  bool _isLoading = false;
  String? _selectedFilePath;
  ImportType _importType = ImportType.append;
  int? _expectedMonth;
  int? _expectedYear;

  ImportResult? _lastImportResult;
  List<ImportHistoryModel> _importHistory = [];
  ImportHistoryModel? _selectedSession;
  List<ImportDetailModel> _sessionDetails = [];

  bool get isLoading => _isLoading;
  String? get selectedFilePath => _selectedFilePath;
  ImportType get importType => _importType;
  int? get expectedMonth => _expectedMonth;
  int? get expectedYear => _expectedYear;
  ImportResult? get lastImportResult => _lastImportResult;
  List<ImportHistoryModel> get importHistory => _importHistory;
  ImportHistoryModel? get selectedSession => _selectedSession;
  List<ImportDetailModel> get sessionDetails => _sessionDetails;

  void setFilePath(String? filePath) {
    _selectedFilePath = filePath;
    notifyListeners();
  }

  void setImportType(ImportType type) {
    _importType = type;
    notifyListeners();
  }

  void setExpectedPeriod(int? month, int? year) {
    _expectedMonth = month;
    _expectedYear = year;
    notifyListeners();
  }

  Future<ImportResult> performImport() async {
    if (_selectedFilePath == null) {
      throw Exception('No file selected');
    }

    _isLoading = true;
    _lastImportResult = null;
    notifyListeners();

    try {
      final result = await _importService.performImport(
        filePath: _selectedFilePath!,
        importType: _importType,
        expectedMonth: _expectedMonth,
        expectedYear: _expectedYear,
      );

      _lastImportResult = result;

      // Refresh history after import
      await loadImportHistory();

      return result;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> validateOnly() async {
    if (_selectedFilePath == null) {
      throw Exception('No file selected');
    }

    _isLoading = true;
    notifyListeners();

    try {
      final result = await _importService.performImport(
        filePath: _selectedFilePath!,
        importType: ImportType.validate_only,
        expectedMonth: _expectedMonth,
        expectedYear: _expectedYear,
      );

      _lastImportResult = result;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ExcelParseResult> getPreviewData() async {
    if (_selectedFilePath == null) {
      throw Exception('No file selected');
    }

    return await _importService.getPreviewData(filePath: _selectedFilePath!);
  }

  Future<void> loadImportHistory() async {
    try {
      _importHistory = await _importService.getImportHistory();
      notifyListeners();
    } catch (e) {
      print('Error loading import history: $e');
    }
  }

  Future<void> loadSessionDetails(int sessionId) async {
    try {
      _selectedSession = await _importService.getImportSession(sessionId);
      _sessionDetails = await _importService.getImportDetails(sessionId);
      notifyListeners();
    } catch (e) {
      print('Error loading session details: $e');
    }
  }

  Future<void> deleteSession(int sessionId) async {
    try {
      await _importService.deleteImportSession(sessionId);
      await loadImportHistory();

      // Clear selected session if it was the one deleted
      if (_selectedSession?.sessionId == sessionId) {
        _selectedSession = null;
        _sessionDetails = [];
      }

      notifyListeners();
    } catch (e) {
      print('Error deleting session: $e');
      rethrow;
    }
  }

  Future<List<ImportHistoryModel>> checkConflictingImports() async {
    if (_expectedMonth == null || _expectedYear == null) {
      return [];
    }

    try {
      return await _importService.checkConflictingImports(
        month: _expectedMonth!,
        year: _expectedYear!,
      );
    } catch (e) {
      print('Error checking conflicts: $e');
      return [];
    }
  }

  void clearResults() {
    _lastImportResult = null;
    _selectedSession = null;
    _sessionDetails = [];
    notifyListeners();
  }

  String getImportSummary() {
    if (_lastImportResult == null) return '';

    final result = _lastImportResult!;
    final buffer = StringBuffer();

    buffer.writeln('Import Summary:');
    buffer.writeln('Status: ${result.success ? "Success" : "Failed"}');
    buffer.writeln(
      'Total Processed: ${result.successCount + result.errorCount}',
    );
    buffer.writeln('Success: ${result.successCount}');

    if (result.errorCount > 0) {
      buffer.writeln('Errors: ${result.errorCount}');
    }

    if (result.duplicateCount > 0) {
      buffer.writeln('Replaced: ${result.duplicateCount}');
    }

    if (result.warnings.isNotEmpty) {
      buffer.writeln('\nWarnings:');
      for (final warning in result.warnings) {
        buffer.writeln('• $warning');
      }
    }

    if (result.errors.isNotEmpty) {
      buffer.writeln('\nErrors:');
      for (final error in result.errors) {
        buffer.writeln('• $error');
      }
    }

    return buffer.toString();
  }

  String getSessionStatusText(String status) {
    switch (status) {
      case 'PROCESSING':
        return 'Processing...';
      case 'SUCCESS':
        return 'Success';
      case 'FAILED':
        return 'Failed';
      case 'VALIDATION_FAILED':
        return 'Validation Failed';
      case 'VALIDATED':
        return 'Validated Only';
      case 'COMPLETED_WITH_ERRORS':
        return 'Completed with Errors';
      default:
        return status;
    }
  }
}

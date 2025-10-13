import 'package:flutter/foundation.dart';
import '../../data/services/enhanced_import_service.dart';
import '../../data/datasources/excel_datasource.dart' as excel_ds;

class EnhancedImportProvider with ChangeNotifier {
  final EnhancedImportService _importService;

  EnhancedImportProvider(this._importService);

  bool _isLoading = false;
  String? _selectedFilePath;
  ImportType _importType = ImportType.append;
  int? _expectedMonth;
  int? _expectedYear;

  ImportResult? _lastImportResult;

  bool get isLoading => _isLoading;
  String? get selectedFilePath => _selectedFilePath;
  ImportType get importType => _importType;
  ImportResult? get lastImportResult => _lastImportResult;
  int? get expectedMonth => _expectedMonth;
  int? get expectedYear => _expectedYear;

  void setFilePath(String path) {
    _selectedFilePath = path;
    _lastImportResult = null;
    notifyListeners();
  }

  void setImportType(ImportType type) {
    _importType = type;
    notifyListeners();
  }

  void setExpectedPeriod(int month, int year) {
    _expectedMonth = month;
    _expectedYear = year;
    notifyListeners();
  }

  void clearExpectedPeriod() {
    _expectedMonth = null;
    _expectedYear = null;
    notifyListeners();
  }

  // Gunakan prefix excel_ds di sini
  Future<excel_ds.ExcelParseResult?> getPreviewData() async {
    if (_selectedFilePath == null) return null;

    _isLoading = true;
    notifyListeners();

    try {
      // Kembalikan tipe dari excel_datasource
      final result = await _importService.getPreviewData(
        filePath: _selectedFilePath!,
      );
      // Karena _importService.getPreviewData mengembalikan Future<ExcelParseResult>
      // dan ExcelParseResult didefinisikan di excel_datasource.dart,
      // maka result sudah benar berupa excel_ds.ExcelParseResult.
      return result;
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ImportResult> performImport() async {
    if (_selectedFilePath == null) {
      throw Exception('No file selected');
    }

    _isLoading = true;
    notifyListeners();

    try {
      final result = await _importService.performImport(
        filePath: _selectedFilePath!,
        importType: _importType,
        expectedMonth: _expectedMonth,
        expectedYear: _expectedYear,
      );

      _lastImportResult = result;
      return result;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void reset() {
    _selectedFilePath = null;
    _lastImportResult = null;
    _expectedMonth = null;
    _expectedYear = null;
    notifyListeners();
  }
}
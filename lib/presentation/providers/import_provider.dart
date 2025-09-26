// lib/presentation/providers/import_provider.dart

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:kupon_bbm_app/data/datasources/excel_datasource.dart';
import 'package:kupon_bbm_app/data/models/kendaraan_model.dart';
import 'package:kupon_bbm_app/data/models/kupon_model.dart';
import 'package:kupon_bbm_app/domain/repositories/kupon_repository.dart';
import 'package:kupon_bbm_app/domain/repositories/kendaraan_repository.dart';

class ImportProvider extends ChangeNotifier {
  final ExcelDatasource _excelDatasource;
  final KuponRepository _kuponRepository;
  final KendaraanRepository _kendaraanRepository;

  ImportProvider(
    this._excelDatasource,
    this._kuponRepository,
    this._kendaraanRepository,
  );

  // State variables (private)
  String? _filePath;
  String _fileName = 'Tidak ada file yang dipilih';
  bool _isLoading = false;
  String _statusMessage = '';
  List<String> _validationMessages = [];
  List<KuponModel> _kupons = [];
  List<KendaraanModel> _newKendaraans = [];

  // Getters (public) - UI akan mengakses ini
  String get fileName => _fileName;
  bool get isLoading => _isLoading;
  String get statusMessage => _statusMessage;
  bool get isFileSelected => _filePath != null;
  List<String> get validationMessages => _validationMessages;
  List<KuponModel> get kupons => _kupons;
  List<KendaraanModel> get newKendaraans => _newKendaraans;

  String getNoPolById(int index) {
    // Gunakan index untuk mendapatkan kendaraan yang sesuai dengan kupon
    if (index >= 0 && index < _newKendaraans.length) {
      final kendaraan = _newKendaraans[index];
      // Format: No Pol - Kode (contoh: 121-VIII)
      return '${kendaraan.noPolNomor}-${kendaraan.noPolKode}';
    }
    return 'N/A';
  }

  // Aksi untuk memilih file
  Future<void> pickFile() async {
    _isLoading = true;
    _statusMessage = '';
    _validationMessages.clear();
    _kupons.clear();
    _newKendaraans.clear();
    notifyListeners();

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result != null) {
        _filePath = result.files.single.path;
        _fileName = result.files.single.name;

        // Parse Excel file segera setelah dipilih
        await _parseExcelFile();
      } else {
        // User membatalkan pemilihan file
        _fileName = 'Pemilihan file dibatalkan.';
        _filePath = null;
        _statusMessage = 'Pemilihan file dibatalkan.';
      }
    } catch (e) {
      _statusMessage = 'Error saat memilih file: $e';
      _filePath = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Method private untuk parsing Excel
  Future<void> _parseExcelFile() async {
    if (_filePath == null) return;

    _statusMessage = 'Membaca file Excel...';
    notifyListeners();

    try {
      // Get existing kupons for validation
      _statusMessage = 'Mengambil data kupon yang ada...';
      notifyListeners();

      final existingKupons = await _kuponRepository.getAllKupon();

      _statusMessage = 'Memvalidasi data Excel...';
      notifyListeners();

      final result = await _excelDatasource.parseExcelFile(
        _filePath!,
        existingKupons.map((e) => e as KuponModel).toList(),
      );

      _kupons = result.kupons;
      _newKendaraans = result.newKendaraans;
      _validationMessages = result.validationMessages;

      if (_validationMessages.isEmpty) {
        _statusMessage =
            'File berhasil dibaca. ${_kupons.length} kupon siap untuk di-import.';
      } else {
        final previewMessages = _validationMessages.take(3).join('\n');
        final remainingCount = _validationMessages.length - 3;
        _statusMessage =
            'File dibaca dengan ${_validationMessages.length} peringatan:\n' +
            previewMessages +
            (remainingCount > 0
                ? '\n...dan $remainingCount peringatan lainnya'
                : '');
      }
    } catch (e) {
      _statusMessage = 'Error saat membaca file: $e';
      _validationMessages.add(_statusMessage);
    }
  }

  // Method private untuk memproses kendaraan baru
  Future<Map<String, int>> _processNewKendaraan() async {
    final Map<String, int> kendaraanIdMap = {};

    for (var kendaraan in _newKendaraans) {
      try {
        // Cek apakah kendaraan sudah ada
        final existing = await _kendaraanRepository.findKendaraanByNoPol(
          kendaraan.noPolKode,
          kendaraan.noPolNomor,
        );

        if (existing != null) {
          // Gunakan ID kendaraan yang sudah ada
          kendaraanIdMap['${kendaraan.noPolKode}${kendaraan.noPolNomor}'] =
              existing.kendaraanId;
        } else {
          // Buat kendaraan baru
          await _kendaraanRepository.insertKendaraan(kendaraan);
          // Cek kembali untuk mendapatkan ID yang baru dibuat
          final created = await _kendaraanRepository.findKendaraanByNoPol(
            kendaraan.noPolKode,
            kendaraan.noPolNomor,
          );
          if (created != null) {
            kendaraanIdMap['${kendaraan.noPolKode}${kendaraan.noPolNomor}'] =
                created.kendaraanId;
          }
        }
      } catch (e) {
        _validationMessages.add(
          'Error saat membuat kendaraan ${kendaraan.noPolKode} ${kendaraan.noPolNomor}: $e',
        );
      }
    }

    return kendaraanIdMap;
  }

  // Aksi untuk memulai import
  Future<void> startImport() async {
    if (_filePath == null) {
      _statusMessage = 'Silakan pilih file terlebih dahulu.';
      notifyListeners();
      return;
    }

    if (_kupons.isEmpty) {
      _statusMessage = 'Tidak ada data valid untuk di-import.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _statusMessage = 'Memulai proses import...';
    notifyListeners();

    try {
      // 1. Proses kendaraan baru
      _statusMessage = 'Memproses data kendaraan...';
      notifyListeners();

      final kendaraanIdMap = await _processNewKendaraan();

      // 2. Update ID kendaraan di kupon
      _statusMessage = 'Mengupdate referensi kendaraan...';
      notifyListeners();

      for (var i = 0; i < _kupons.length; i++) {
        final kupon = _kupons[i];
        final kendaraan = _newKendaraans[i];
        final key = '${kendaraan.noPolKode}${kendaraan.noPolNomor}';

        if (kendaraanIdMap.containsKey(key)) {
          _kupons[i] = kupon.copyWith(kendaraanId: kendaraanIdMap[key]!);
        } else {
          _validationMessages.add(
            'Gagal mendapatkan ID kendaraan untuk kupon ${kupon.nomorKupon}',
          );
          continue;
        }
      }

      // 3. Import kupon
      _statusMessage = 'Mengimport kupon...';
      notifyListeners();

      for (var kupon in _kupons) {
        if (kupon.kendaraanId > 0) {
          await _kuponRepository.insertKupon(kupon);
        }
      }

      _statusMessage = 'Import ${_kupons.length} kupon selesai!';
      if (_validationMessages.isNotEmpty) {
        _statusMessage +=
            '\nTerdapat ${_validationMessages.length} peringatan.';
      }
    } catch (e) {
      _statusMessage = 'Error saat import: $e';
    } finally {
      _isLoading = false;
      _filePath = null; // Reset setelah selesai
      _fileName = 'Tidak ada file yang dipilih';
      _kupons.clear();
      _newKendaraans.clear();
      notifyListeners();
    }
  }
}

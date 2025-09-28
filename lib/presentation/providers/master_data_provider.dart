import 'package:flutter/material.dart';
import '../../../domain/entities/satker_entity.dart';
import '../../../domain/repositories/master_data_repository.dart';

class MasterDataProvider extends ChangeNotifier {
  final MasterDataRepository _masterDataRepository;

  MasterDataProvider(this._masterDataRepository);

  List<SatkerEntity> _satkerList = [];
  List<SatkerEntity> get satkerList => _satkerList;

  Future<void> fetchSatkers() async {
    try {
      final satkers = await _masterDataRepository.getAllSatker();
      _satkerList = satkers;
      print('DEBUG: Loaded ${satkers.length} satkers');
      for (var satker in satkers) {
        print(
          'DEBUG: Satker: id=${satker.satkerId}, name=${satker.namaSatker}',
        );
      }
      notifyListeners();
    } catch (e, stackTrace) {
      print('ERROR: Failed to fetch satkers: $e');
      print(stackTrace);
      _satkerList = [];
      notifyListeners();
    }
  }

  List<Map<String, dynamic>> _jenisBBMList = [];
  List<Map<String, dynamic>> get jenisBBMList => _jenisBBMList;

  List<Map<String, dynamic>> _jenisKuponList = [];
  List<Map<String, dynamic>> get jenisKuponList => _jenisKuponList;

  Future<void> fetchJenisBBM() async {
    try {
      final jenisBBM = await _masterDataRepository.getAllJenisBBM();
      _jenisBBMList = jenisBBM;
      notifyListeners();
    } catch (e) {
      // Handle error
      _jenisBBMList = [];
      notifyListeners();
    }
  }

  Future<void> fetchJenisKupon() async {
    try {
      final jenisKupon = await _masterDataRepository.getAllJenisKupon();
      _jenisKuponList = jenisKupon;
      notifyListeners();
    } catch (e) {
      // Handle error
      _jenisKuponList = [];
      notifyListeners();
    }
  }
}

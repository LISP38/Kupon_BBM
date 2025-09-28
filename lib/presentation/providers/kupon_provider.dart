import 'package:flutter/material.dart';
import '../../../domain/entities/kupon_entity.dart';
import '../../../domain/repositories/kupon_repository.dart';

class KuponProvider extends ChangeNotifier {
  final KuponRepository _kuponRepository;

  KuponProvider(this._kuponRepository);

  List<KuponEntity> _kuponList = [];
  List<KuponEntity> get kuponList => _kuponList;

  Future<void> fetchKupons() async {
    try {
      final kupons = await _kuponRepository.getAllKupon();
      _kuponList = kupons;
      notifyListeners();
    } catch (e) {
      // Handle error
      _kuponList = [];
      notifyListeners();
    }
  }

  Future<KuponEntity?> getKuponById(int id) async {
    try {
      return await _kuponRepository.getKuponById(id);
    } catch (e) {
      return null;
    }
  }

  Future<KuponEntity?> getKuponByNomor(String nomorKupon) async {
    try {
      return await _kuponRepository.getKuponByNomorKupon(nomorKupon);
    } catch (e) {
      return null;
    }
  }

  Future<void> addKupon(KuponEntity kupon) async {
    try {
      await _kuponRepository.insertKupon(kupon);
      await fetchKupons(); // Refresh list after adding
    } catch (e) {
      // Handle error
    }
  }

  Future<void> updateKupon(KuponEntity kupon) async {
    try {
      await _kuponRepository.updateKupon(kupon);
      await fetchKupons(); // Refresh list after updating
    } catch (e) {
      // Handle error
    }
  }
}

import 'package:flutter/material.dart';
import 'package:kupon_bbm_app/domain/entities/kupon_entity.dart';
import 'package:kupon_bbm_app/domain/repositories/kupon_repository.dart';

class DashboardProvider extends ChangeNotifier {
  final KuponRepository _kuponRepository;

  List<KuponEntity> _kupons = [];
  List<KuponEntity> get kupons => _kupons;

  // Filter state
  String? nomorKupon;
  String? satker;
  String? jenisBBM;
  String? jenisKupon;
  String? nopol;
  int? bulanTerbit;
  int? tahunTerbit;

  DashboardProvider(this._kuponRepository);

  Future<void> fetchKupons() async {
    // TODO: Implementasi filter ke repository
    _kupons = await _kuponRepository.getAllKupon();
    print('[DASHBOARD] fetchKupons: jumlah data = ${_kupons.length}');
    for (final k in _kupons) {
      print('[DASHBOARD] kupon: id=${k.kuponId}, nomor=${k.nomorKupon}, kendaraanId=${k.kendaraanId}, isDeleted=${k.isDeleted}, status=${k.status}');
    }
    notifyListeners();
  }

  void setFilter({
    String? nomorKupon,
    String? satker,
    String? jenisBBM,
    String? jenisKupon,
    String? nopol,
    int? bulanTerbit,
    int? tahunTerbit,
  }) {
    this.nomorKupon = nomorKupon;
    this.satker = satker;
    this.jenisBBM = jenisBBM;
    this.jenisKupon = jenisKupon;
    this.nopol = nopol;
    this.bulanTerbit = bulanTerbit;
    this.tahunTerbit = tahunTerbit;
    fetchKupons();
  }
}

import 'package:flutter/material.dart';
import 'package:kupon_bbm_app/domain/entities/kupon_entity.dart';
import 'package:kupon_bbm_app/data/models/kupon_model.dart';
import 'package:kupon_bbm_app/domain/repositories/kupon_repository.dart';
import 'package:kupon_bbm_app/domain/repositories/kupon_repository_impl.dart';

class DashboardProvider extends ChangeNotifier {
  final KuponRepository _kuponRepository;

  List<KuponEntity> _kupons = [];
  List<KuponEntity> get kupons => _kupons;
  List<KuponEntity> get kuponList => _kupons;

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
    final db = await ( _kuponRepository as KuponRepositoryImpl ).dbHelper.database;
    // Ambil semua data kupon dari DB
    final allKupons = await db.query('fact_kupon', where: 'is_deleted = 0');
    print('[DASHBOARD][ALL] Semua data fact_kupon:');
    for (final map in allKupons) {
      print(map);
    }
    // Filter data sesuai state
    List<KuponEntity> filtered = allKupons.map((map) => KuponModel.fromMap(map)).toList();
    if (nomorKupon != null && nomorKupon!.isNotEmpty) {
      filtered = filtered.where((k) => k.nomorKupon.contains(nomorKupon!)).toList();
    }
    if (jenisKupon != null && jenisKupon!.isNotEmpty) {
      filtered = filtered.where((k) => k.jenisKuponId.toString() == jenisKupon || k.jenisKuponId == int.tryParse(jenisKupon!)).toList();
    }
    if (jenisBBM != null && jenisBBM!.isNotEmpty) {
      filtered = filtered.where((k) => k.jenisBbmId.toString() == jenisBBM || k.jenisBbmId == int.tryParse(jenisBBM!)).toList();
    }
    if (nopol != null && nopol!.isNotEmpty) {
      filtered = filtered.where((k) => k.kendaraanId.toString() == nopol).toList(); // Bisa diimprove dengan join kendaraan
    }
    if (bulanTerbit != null) {
      filtered = filtered.where((k) => k.bulanTerbit == bulanTerbit).toList();
    }
    if (tahunTerbit != null) {
      filtered = filtered.where((k) => k.tahunTerbit == tahunTerbit).toList();
    }
    if (satker != null && satker!.isNotEmpty) {
      // Butuh join ke kendaraan, sementara skip dulu
    }
    _kupons = filtered;
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
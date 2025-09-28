import 'package:flutter/material.dart';
import 'package:kupon_bbm_app/domain/entities/transaksi_entity.dart';
import 'package:kupon_bbm_app/domain/repositories/transaksi_repository_impl.dart';

class TransaksiProvider extends ChangeNotifier {
  final TransaksiRepositoryImpl _transaksiRepository;

  List<TransaksiEntity> _transaksiList = [];
  List<Map<String, dynamic>> _kuponMinusList = [];

  int? filterBulan;
  int? filterTahun;
  int? filterHari;
  String? filterNomorKupon;
  String? filterSatker;
  int? filterJenisBbmId;

  TransaksiProvider(this._transaksiRepository);

  List<TransaksiEntity> get transaksiList => _transaksiList;
  List<Map<String, dynamic>> get kuponMinusList => _kuponMinusList;

  Future<void> fetchTransaksi() async {
    _transaksiList = await _transaksiRepository.getAllTransaksi();
    notifyListeners();
  }

  Future<bool> createTransaksi({
    required int kuponId,
    required double jumlahLiter,
  }) async {
    final success = await _transaksiRepository.createTransaksi(
      kuponId: kuponId,
      jumlahLiter: jumlahLiter,
    );

    if (success) {
      // Refresh data after successful transaction
      await fetchTransaksiFiltered();
    }

    return success;
  }

  Future<void> fetchTransaksiFiltered() async {
    _transaksiList = await _transaksiRepository.getAllTransaksi(
      bulan: filterBulan,
      tahun: filterTahun,
      hari: filterHari,
      nomorKupon: filterNomorKupon,
      satker: filterSatker,
      jenisBbmId: filterJenisBbmId,
    );
    notifyListeners();
  }

  Future<void> fetchKuponMinus() async {
    _kuponMinusList = await _transaksiRepository.getKuponMinus();
    notifyListeners();
  }

  Future<void> addTransaksi(TransaksiEntity transaksi) async {
    await _transaksiRepository.insertTransaksi(transaksi);
    await fetchTransaksiFiltered();
    await fetchKuponMinus();
  }

  void setBulan(int bulan) {
    filterBulan = bulan;
    notifyListeners();
  }

  void setTahun(int tahun) {
    filterTahun = tahun;
    notifyListeners();
  }

  void resetFilter() {
    filterBulan = null;
    filterTahun = null;
    filterHari = null;
    filterNomorKupon = null;
    filterSatker = null;
    filterJenisBbmId = null;
    notifyListeners();
  }

  Future<void> updateTransaksi(TransaksiEntity transaksi) async {
    await _transaksiRepository.updateTransaksi(transaksi);
    await fetchTransaksiFiltered();
    await fetchKuponMinus();
  }

  Future<void> deleteTransaksi(int transaksiId) async {
    await _transaksiRepository.deleteTransaksi(transaksiId);
    await fetchTransaksiFiltered();
    await fetchKuponMinus();
  }

  void setFilterTransaksi({
    int? hari,
    int? bulan,
    int? tahun,
    String? nomorKupon,
    String? satker,
    int? jenisBbmId,
  }) {
    filterHari = hari ?? filterHari;
    filterBulan = bulan ?? filterBulan;
    filterTahun = tahun ?? filterTahun;
    filterNomorKupon = nomorKupon ?? filterNomorKupon;
    filterSatker = satker ?? filterSatker;
    filterJenisBbmId = jenisBbmId ?? filterJenisBbmId;
    fetchTransaksiFiltered();
  }
}

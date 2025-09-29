import '../entities/transaksi_entity.dart';

abstract class TransaksiRepository {
  Future<List<TransaksiEntity>> getAllTransaksi({
    int? bulan,
    int? tahun,
    int? isDeleted,
  });
  Future<TransaksiEntity?> getTransaksiById(int transaksiId);
  Future<void> insertTransaksi(TransaksiEntity transaksi);
  Future<void> updateTransaksi(TransaksiEntity transaksi);
  Future<void> deleteTransaksi(int transaksiId);
  Future<List<Map<String, dynamic>>> getKuponMinus();
  Future<void> restoreTransaksi(int transaksiId);
}

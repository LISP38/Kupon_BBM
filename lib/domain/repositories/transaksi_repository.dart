import '../entities/transaksi_entity.dart';

abstract class TransaksiRepository {
  Future<List<TransaksiEntity>> getAllTransaksi();
  Future<TransaksiEntity?> getTransaksiById(int transaksiId);
  Future<void> insertTransaksi(TransaksiEntity transaksi);
  Future<void> updateTransaksi(TransaksiEntity transaksi);
  Future<void> deleteTransaksi(int transaksiId);
}

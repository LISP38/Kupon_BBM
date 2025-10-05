import '../entities/kendaraan_entity.dart';

abstract class KendaraanRepository {
  Future<List<KendaraanEntity>> getAllKendaraan();
  Future<KendaraanEntity?> getKendaraanById(int kendaraanId);
  Future<int> insertKendaraan(KendaraanEntity kendaraan);
  Future<void> updateKendaraan(KendaraanEntity kendaraan);
  Future<void> deleteKendaraan(int kendaraanId);

  // Tambahan method untuk mencari kendaraan berdasarkan noPol
  Future<KendaraanEntity?> findKendaraanByNoPol(
    String noPolKode,
    String noPolNomor,
  );
  // Method untuk batch insert kendaraan
  Future<List<int>> insertManyKendaraan(List<KendaraanEntity> kendaraans);
}

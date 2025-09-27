import '../entities/kupon_entity.dart';

abstract class KuponRepository {
  Future<List<KuponEntity>> getAllKupon();
  Future<KuponEntity?> getKuponById(int kuponId);
  Future<void> insertKupon(KuponEntity kupon);
  Future<void> updateKupon(KuponEntity kupon);
  Future<void> deleteKupon(int kuponId);
  Future<KuponEntity?> getKuponByNomorKupon(String nomorKupon);
  Future<void> deleteAllKupon();
}

import '../entities/satker_entity.dart';

abstract class MasterDataRepository {
  Future<List<SatkerEntity>> getAllSatker();
  Future<List<Map<String, dynamic>>> getAllJenisBBM();
  Future<List<Map<String, dynamic>>> getAllJenisKupon();
}

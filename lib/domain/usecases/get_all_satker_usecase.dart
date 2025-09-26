import '../entities/satker_entity.dart';
import '../repositories/master_data_repository.dart';

class GetAllSatkerUseCase {
  final MasterDataRepository repository;

  GetAllSatkerUseCase(this.repository);

  Future<List<SatkerEntity>> execute() async {
    return await repository.getAllSatker();
  }
}

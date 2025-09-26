import '../entities/kupon_entity.dart';
import '../repositories/kupon_repository.dart';

class GetKuponForTransactionUseCase {
  final KuponRepository repository;

  GetKuponForTransactionUseCase(this.repository);

  /// Cari kupon berdasarkan ID atau Nomor Kupon (tergantung implementasi repository)
  Future<KuponEntity?> execute(int kuponId) async {
    return await repository.getKuponById(kuponId);
  }
}

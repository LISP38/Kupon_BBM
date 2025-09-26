import '../entities/transaksi_entity.dart';
import '../repositories/transaksi_repository.dart';

class GetAllTransactionsUseCase {
  final TransaksiRepository repository;

  GetAllTransactionsUseCase(this.repository);

  Future<List<TransaksiEntity>> execute() async {
    return await repository.getAllTransaksi();
  }
}

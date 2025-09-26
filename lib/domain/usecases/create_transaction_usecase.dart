import '../entities/transaksi_entity.dart';
import '../repositories/transaksi_repository.dart';

class CreateTransactionUseCase {
  final TransaksiRepository repository;

  CreateTransactionUseCase(this.repository);

  Future<void> execute(TransaksiEntity transaksi) async {
    await repository.insertTransaksi(transaksi);
  }
}

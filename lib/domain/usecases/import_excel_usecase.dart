// lib/domain/usecases/import_excel_usecase.dart

import 'package:kupon_bbm_app/domain/entities/kupon_entity.dart';
import 'package:kupon_bbm_app/domain/repositories/kupon_repository.dart';

// Class untuk menampung hasil import
class ImportResult {
  final int successCount;
  final int failureCount;
  final List<String> errorMessages;

  ImportResult({
    this.successCount = 0,
    this.failureCount = 0,
    this.errorMessages = const [],
  });
}

class ImportExcelUseCase {
  final KuponRepository kuponRepository;
  // Nanti kita akan tambahkan repository lain jika perlu validasi ke tabel lain

  ImportExcelUseCase(this.kuponRepository);

  Future<ImportResult> call(List<KuponEntity> kuponsFromExcel) async {
    int success = 0;
    int failed = 0;
    List<String> errors = [];

    for (var kupon in kuponsFromExcel) {
      try {
        // Lakukan validasi bisnis di sini jika perlu
        if (kupon.nomorKupon.isEmpty) {
          throw Exception('Nomor kupon tidak boleh kosong.');
        }

        // Cek apakah kupon sudah ada, jika sudah update, jika belum tambah
        // (Logika ini bisa disempurnakan sesuai kebutuhan 'replace' di spek)
        final existingKupon = await kuponRepository.getKuponById(kupon.kuponId);
        
        if (existingKupon != null) {
          // Logika update (misalnya, update kuota atau tanggal)
          // Untuk sekarang kita lewati dulu agar tidak duplikat
           throw Exception('Kupon ${kupon.nomorKupon} sudah ada.');
        } else {
          await kuponRepository.insertKupon(kupon);
        }
        
        success++;
      } catch (e) {
        failed++;
        errors.add('Gagal import kupon ${kupon.nomorKupon}: ${e.toString()}');
      }
    }

    return ImportResult(
      successCount: success,
      failureCount: failed,
      errorMessages: errors,
    );
  }
}
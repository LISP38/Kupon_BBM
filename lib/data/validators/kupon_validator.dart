import 'package:kupon_bbm_app/data/models/kupon_model.dart';
import 'package:kupon_bbm_app/data/models/kendaraan_model.dart';
import 'package:kupon_bbm_app/domain/repositories/kendaraan_repository.dart';

class KuponValidationResult {
  final bool isValid;
  final List<String> messages;

  KuponValidationResult({required this.isValid, this.messages = const []});
}

class KuponValidator {
  final KendaraanRepository _kendaraanRepository;

  KuponValidator(this._kendaraanRepository);

  // Validasi satu kendaraan hanya boleh memiliki satu jenis BBM
  KuponValidationResult validateBBMPerKendaraan(
    List<KuponModel> existingKupons,
    KuponModel newKupon,
    String noPol,
    int kendaraanId,
  ) {
    // Cek kupon yang sudah ada untuk kendaraan yang sama
    final kendaraanKupons = existingKupons
        .where((k) => k.kendaraanId == kendaraanId)
        .toList();

    if (kendaraanKupons.isNotEmpty &&
        kendaraanKupons.any((k) => k.jenisBbmId != newKupon.jenisBbmId)) {
      return KuponValidationResult(
        isValid: false,
        messages: [
          'Kendaraan dengan No Pol $noPol sudah memiliki kupon dengan jenis BBM berbeda',
        ],
      );
    }

    return KuponValidationResult(isValid: true);
  }

  // Validasi maksimal 2 kupon per bulan (1 Ranjen + 1 Dukungan) - DINONAKTIFKAN UNTUK IMPORT
  KuponValidationResult validateKuponPerBulan(
    List<KuponModel> existingKupons,
    KuponModel newKupon,
    String noPol,
    int kendaraanId,
  ) {
    // Sementara dinonaktifkan validasi jumlah kupon per bulan untuk import
    // Untuk mengizinkan import multiple kupon jenis yang sama
    return KuponValidationResult(isValid: true);
  }

  // Validasi tanggal berlaku (2 bulan dari terbit)
  KuponValidationResult validateDateRange(KuponModel kupon) {
    final tanggalMulai = DateTime.parse(kupon.tanggalMulai);
    final tanggalSampai = DateTime.parse(kupon.tanggalSampai);
    final selisihHari = tanggalSampai.difference(tanggalMulai).inDays;

    // Validasi maksimum 2 bulan (62 hari untuk mengakomodasi bulan dengan 31 hari)
    if (selisihHari > 62) {
      return KuponValidationResult(
        isValid: false,
        messages: [
          'Periode kupon tidak boleh lebih dari 2 bulan (${kupon.nomorKupon})',
        ],
      );
    }

    // Validasi tanggal mulai harus awal bulan
    if (tanggalMulai.day != 1) {
      return KuponValidationResult(
        isValid: false,
        messages: ['Tanggal mulai harus tanggal 1 (${kupon.nomorKupon})'],
      );
    }

    return KuponValidationResult(isValid: true);
  }

  // Validasi keseluruhan untuk satu kupon
  Future<KuponValidationResult> validateKupon(
    List<KuponModel> existingKupons,
    KuponModel newKupon,
    String noPol, {
    bool allowReplace = false,
  }) async {
    final List<String> allMessages = [];

    int tempKendaraanId = newKupon.kendaraanId;
    if (tempKendaraanId == 0) {
      final parts = noPol.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        final kode = parts[0];
        final nomor = parts[1];
        final existingKendaraan = await _kendaraanRepository.findKendaraanByNoPol(kode, nomor);
        if (existingKendaraan != null) {
          tempKendaraanId = existingKendaraan.kendaraanId;
        }
      }
    }

    // Validasi jenis BBM
    final bbmResult = validateBBMPerKendaraan(existingKupons, newKupon, noPol, tempKendaraanId);
    if (!bbmResult.isValid) {
      allMessages.addAll(bbmResult.messages);
    }

    // Validasi jumlah kupon per bulan (skip jika allowReplace)
    if (!allowReplace) {
      final kuponPerBulanResult = validateKuponPerBulan(
        existingKupons,
        newKupon,
        noPol,
        tempKendaraanId,
      );
      if (!kuponPerBulanResult.isValid) {
        allMessages.addAll(kuponPerBulanResult.messages);
      }
    }

    // Validasi range tanggal
    final dateResult = validateDateRange(newKupon);
    if (!dateResult.isValid) {
      allMessages.addAll(dateResult.messages);
    }

    return KuponValidationResult(
      isValid: allMessages.isEmpty,
      messages: allMessages,
    );
  }
}

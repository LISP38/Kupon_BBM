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
  ) {
    // Cek kupon yang sudah ada untuk kendaraan yang sama
    final kendaraanKupons = existingKupons
        .where((k) => k.kendaraanId == newKupon.kendaraanId)
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

  // Validasi maksimal 2 kupon per bulan (1 Ranjen + 1 Dukungan)
  KuponValidationResult validateKuponPerBulan(
    List<KuponModel> existingKupons,
    KuponModel newKupon,
    String noPol,
  ) {
    // Cek kupon yang sudah ada untuk bulan dan tahun yang sama
    final periodKupons = existingKupons
        .where(
          (k) =>
              k.kendaraanId == newKupon.kendaraanId &&
              k.bulanTerbit == newKupon.bulanTerbit &&
              k.tahunTerbit == newKupon.tahunTerbit,
        )
        .toList();

    // Hitung jumlah kupon Ranjen dan Dukungan
    final ranjenCount = periodKupons.where((k) => k.jenisKuponId == 1).length;
    final dukunganCount = periodKupons.where((k) => k.jenisKuponId == 2).length;

    if (newKupon.jenisKuponId == 1 && ranjenCount >= 1) {
      return KuponValidationResult(
        isValid: false,
        messages: [
          'Kendaraan dengan No Pol $noPol sudah memiliki kupon Ranjen untuk periode ${newKupon.bulanTerbit}/${newKupon.tahunTerbit}',
        ],
      );
    }

    if (newKupon.jenisKuponId == 2 && dukunganCount >= 1) {
      return KuponValidationResult(
        isValid: false,
        messages: [
          'Kendaraan dengan No Pol $noPol sudah memiliki kupon Dukungan untuk periode ${newKupon.bulanTerbit}/${newKupon.tahunTerbit}',
        ],
      );
    }

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
  KuponValidationResult validateKupon(
    List<KuponModel> existingKupons,
    KuponModel newKupon,
    String noPol,
  ) {
    final List<String> allMessages = [];

    // Validasi jenis BBM
    final bbmResult = validateBBMPerKendaraan(existingKupons, newKupon, noPol);
    if (!bbmResult.isValid) {
      allMessages.addAll(bbmResult.messages);
    }

    // Validasi jumlah kupon per bulan
    final kuponPerBulanResult = validateKuponPerBulan(
      existingKupons,
      newKupon,
      noPol,
    );
    if (!kuponPerBulanResult.isValid) {
      allMessages.addAll(kuponPerBulanResult.messages);
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

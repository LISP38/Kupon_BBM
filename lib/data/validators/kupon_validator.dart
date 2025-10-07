import 'package:kupon_bbm_app/data/models/kupon_model.dart';

class KuponValidationResult {
  final bool isValid;
  final List<String> messages;

  KuponValidationResult({required this.isValid, this.messages = const []});
}

class KuponValidator {
  KuponValidator();

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

  // Validasi duplikat berdasarkan nomor kupon
  KuponValidationResult validateDuplicate(
    List<KuponModel> existingKupons,
    KuponModel newKupon,
    String noPol, {
    List<KuponModel>? currentBatchKupons,
  }) {
    // Gabungkan existing dan current batch untuk deteksi duplikat yang lebih komprehensif
    final allKupons = [
      ...existingKupons,
      if (currentBatchKupons != null) ...currentBatchKupons,
    ];

    // PERBAIKAN LENGKAP: Duplikat harus mempertimbangkan ranmor untuk RANJEN
    // PRINSIP BARU: Duplikat hanya ditolak jika SEMUA field benar-benar identik
    // Nomor kupon yang sama DIIZINKAN selama ada perbedaan di field lain

    // Cari kupon yang BENAR-BENAR IDENTIK (semua field sama)
    final duplicate = allKupons.where((k) {
      final isIdentical =
          k.nomorKupon == newKupon.nomorKupon &&
          k.bulanTerbit == newKupon.bulanTerbit &&
          k.tahunTerbit == newKupon.tahunTerbit &&
          k.jenisKuponId == newKupon.jenisKuponId &&
          k.satkerId == newKupon.satkerId &&
          k.jenisBbmId == newKupon.jenisBbmId &&
          k.kendaraanId == newKupon.kendaraanId &&
          k.kuotaAwal == newKupon.kuotaAwal;

      // Debug logging untuk kupon dengan nomor sama
      if (k.nomorKupon == newKupon.nomorKupon) {
        print('DEBUG DUPLICATE CHECK for kupon ${newKupon.nomorKupon}:');
        print(
          '  Existing: satker=${k.satkerId}, bbm=${k.jenisBbmId}, kendaraan=${k.kendaraanId}, kuota=${k.kuotaAwal}',
        );
        print(
          '  New:      satker=${newKupon.satkerId}, bbm=${newKupon.jenisBbmId}, kendaraan=${newKupon.kendaraanId}, kuota=${newKupon.kuotaAwal}',
        );
        print('  Identical: $isIdentical');
      }

      return isIdentical;
      // Jika SEMUA field di atas sama, baru dianggap duplikat sejati
    }).toList();

    if (duplicate.isNotEmpty) {
      // Cek apakah duplikat identik dari database atau batch saat ini
      final duplicateFromDatabase = existingKupons.any((k) {
        return k.nomorKupon == newKupon.nomorKupon &&
            k.bulanTerbit == newKupon.bulanTerbit &&
            k.tahunTerbit == newKupon.tahunTerbit &&
            k.jenisKuponId == newKupon.jenisKuponId &&
            k.satkerId == newKupon.satkerId &&
            k.jenisBbmId == newKupon.jenisBbmId &&
            k.kendaraanId == newKupon.kendaraanId &&
            k.kuotaAwal == newKupon.kuotaAwal;
      });

      final duplicateFromCurrentBatch = (currentBatchKupons ?? []).any((k) {
        return k.nomorKupon == newKupon.nomorKupon &&
            k.bulanTerbit == newKupon.bulanTerbit &&
            k.tahunTerbit == newKupon.tahunTerbit &&
            k.jenisKuponId == newKupon.jenisKuponId &&
            k.satkerId == newKupon.satkerId &&
            k.jenisBbmId == newKupon.jenisBbmId &&
            k.kendaraanId == newKupon.kendaraanId &&
            k.kuotaAwal == newKupon.kuotaAwal;
      });

      String duplicateSource = '';
      if (duplicateFromDatabase && duplicateFromCurrentBatch) {
        duplicateSource = ' (ada di DATABASE dan BATCH saat ini)';
      } else if (duplicateFromDatabase) {
        duplicateSource = ' (sudah ada di DATABASE dari import sebelumnya)';
      } else if (duplicateFromCurrentBatch) {
        duplicateSource = ' (duplikat dalam FILE EXCEL yang sama)';
      }

      // Get BBM type name untuk pesan yang lebih jelas
      final bbmName = newKupon.jenisBbmId == 1
          ? 'Pertamax'
          : 'Dex'; // Hanya ada Pertamax (1) dan Dex (2)

      final jenisKuponName = newKupon.jenisKuponId == 1 ? 'RANJEN' : 'DUKUNGAN';

      // Pesan untuk duplikat identik (semua field sama)
      final detailMessage =
          'DUPLIKAT IDENTIK: Kupon $jenisKuponName ${newKupon.nomorKupon} ($bbmName) '
          'untuk satker ${newKupon.namaSatker} dengan SEMUA data yang sama sudah ada di sistem '
          'untuk periode ${newKupon.bulanTerbit}/${newKupon.tahunTerbit}$duplicateSource. '
          'Data: kuota=${newKupon.kuotaAwal}, kendaraanId=${newKupon.kendaraanId}';

      return KuponValidationResult(isValid: false, messages: [detailMessage]);
    }

    return KuponValidationResult(isValid: true);
  }

  // Validasi eligibilitas satker untuk dukungan
  // PERBAIKAN: Hilangkan pembatasan eligibilitas - semua satker bisa mendapat kupon DUKUNGAN
  KuponValidationResult validateSatkerEligibilityForDukungan(
    KuponModel newKupon,
  ) {
    // TIDAK ADA PEMBATASAN LAGI - semua satker eligible untuk kupon DUKUNGAN
    if (newKupon.jenisKuponId == 2) {
      print(
        'INFO: Kupon DUKUNGAN untuk satker ${newKupon.namaSatker} - DIIZINKAN (pembatasan dihapus)',
      );
    }
    return KuponValidationResult(isValid: true);
  }

  // Validasi dukungan bergantung pada ranjen - IMPROVED VERSION
  KuponValidationResult validateDukunganRequiresRanjen(
    List<KuponModel> existingKupons,
    KuponModel newKupon, {
    List<KuponModel>? currentBatchKupons, // Kupon dalam batch import yang sama
  }) {
    if (newKupon.jenisKuponId == 2) {
      // 2 = DUKUNGAN

      // CADANGAN DUKUNGAN tidak memerlukan RANJEN - mereka adalah kupon cadangan murni
      if (newKupon.namaSatker.toUpperCase() == 'CADANGAN') {
        return KuponValidationResult(isValid: true);
      }

      // SOLUSI: Lebih permisif untuk DUKUNGAN - hanya warning jika tidak ada RANJEN
      final allKupons = [
        ...existingKupons,
        if (currentBatchKupons != null) ...currentBatchKupons,
      ];

      // Cek apakah ada kupon RANJEN untuk satker yang sama di periode yang sama
      final ranjenExists = allKupons.any(
        (k) =>
            k.satkerId == newKupon.satkerId &&
            k.jenisKuponId == 1 && // 1 = RANJEN
            k.bulanTerbit == newKupon.bulanTerbit &&
            k.tahunTerbit == newKupon.tahunTerbit,
      );

      if (!ranjenExists) {
        // PERBAIKAN: Hanya warning, bukan error keras - biarkan DUKUNGAN diproses
        // Ini mengatasi masalah urutan processing dalam file Excel
        print(
          'WARNING: Kupon DUKUNGAN ${newKupon.nomorKupon} tidak memiliki RANJEN yang sesuai, tapi akan tetap diproses',
        );
        // Return valid dengan warning
        return KuponValidationResult(isValid: true);
      }
    }
    return KuponValidationResult(isValid: true);
  }

  // Validasi keseluruhan untuk satu kupon
  KuponValidationResult validateKupon(
    List<KuponModel> existingKupons,
    KuponModel newKupon,
    String noPol, {
    List<KuponModel>? currentBatchKupons, // Kupon dalam batch import yang sama
  }) {
    final List<String> allMessages = [];

    // Validasi duplikat PERTAMA - ini yang paling penting
    final duplicateResult = validateDuplicate(
      existingKupons,
      newKupon,
      noPol,
      currentBatchKupons: currentBatchKupons,
    );
    if (!duplicateResult.isValid) {
      allMessages.addAll(duplicateResult.messages);
    }

    if (newKupon.jenisKuponId == 1) {
      // VALIDASI RANJEN (berbasis kendaraan)
      if (newKupon.kendaraanId == null) {
        allMessages.add('Kupon RANJEN harus memiliki data kendaraan');
      } else {
        // Validasi jenis BBM
        final bbmResult = validateBBMPerKendaraan(
          existingKupons,
          newKupon,
          noPol,
        );
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
      }
    } else if (newKupon.jenisKuponId == 2) {
      // VALIDASI DUKUNGAN (berbasis satker)

      // Validasi eligibilitas satker
      final eligibilityResult = validateSatkerEligibilityForDukungan(newKupon);
      if (!eligibilityResult.isValid) {
        allMessages.addAll(eligibilityResult.messages);
      }

      // Validasi ketergantungan pada RANJEN
      final ranjenDependencyResult = validateDukunganRequiresRanjen(
        existingKupons,
        newKupon,
        currentBatchKupons: currentBatchKupons,
      );
      if (!ranjenDependencyResult.isValid) {
        allMessages.addAll(ranjenDependencyResult.messages);
      }
    }

    // Validasi range tanggal (berlaku untuk kedua jenis)
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

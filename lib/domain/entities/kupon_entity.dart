class KuponEntity {
  final int kuponId;
  final String nomorKupon;
  final int? kendaraanId; // Nullable for DUKUNGAN
  final int jenisBbmId;
  final int jenisKuponId;
  final int bulanTerbit;
  final int tahunTerbit;
  final String tanggalMulai;
  final String tanggalSampai;
  final double kuotaAwal;
  final double kuotaSisa;
  final int satkerId;
  final String namaSatker;
  final String status;
  final String? createdAt;
  final String? updatedAt;
  final int isDeleted;

  const KuponEntity({
    required this.kuponId,
    required this.nomorKupon,
    this.kendaraanId, // Optional for DUKUNGAN
    required this.jenisBbmId,
    required this.jenisKuponId,
    required this.bulanTerbit,
    required this.tahunTerbit,
    required this.tanggalMulai,
    required this.tanggalSampai,
    required this.kuotaAwal,
    required this.kuotaSisa,
    required this.satkerId,
    required this.namaSatker,
    this.status = 'Aktif',
    this.createdAt,
    this.updatedAt,
    this.isDeleted = 0,
  });

  /// Determine actual kupon status based on date validity and quota
  /// Returns: 'Kadaluarsa', 'Belum Aktif', 'Habis', 'Terpakai', or 'Tersedia'
  String getActualStatus() {
    final today = DateTime.now();

    try {
      final tanggalMulai = DateTime.parse(this.tanggalMulai);
      final tanggalSampai = DateTime.parse(this.tanggalSampai);

      // First check: date validity
      if (today.isBefore(tanggalMulai)) {
        return 'Belum Aktif';
      }

      // Check if today is after the end date (same day is still valid)
      final tomorrowAfterEnd = tanggalSampai.add(Duration(days: 1));
      if (today.isAfter(tomorrowAfterEnd)) {
        return 'Kadaluarsa';
      }

      // If within valid date range, check quota status
      if (kuotaSisa <= 0) {
        return 'Habis';
      }

      if (kuotaSisa < kuotaAwal) {
        return 'Terpakai';
      }

      return 'Tersedia';
    } catch (e) {
      // Fallback to status from database if date parsing fails
      return status;
    }
  }
}

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
}

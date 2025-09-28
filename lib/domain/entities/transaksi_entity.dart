class TransaksiEntity {
  final int purchasingId;
  final int kuponId;
  final String nomorKupon;
  final int kendaraanId;
  final int satkerId;
  final int jenisBbmId;
  final int jenisKuponId;
  final String tanggalTransaksi;
  final double jumlahDiambil;
  final String? keterangan;
  final String? createdAt;
  final int isDeleted;
  final String? deletedAt;
  final String status;

  String get jenisBbm => jenisBbmId.toString();

  const TransaksiEntity({
    required this.purchasingId,
    required this.kuponId,
    required this.nomorKupon,
    required this.kendaraanId,
    required this.satkerId,
    required this.jenisBbmId,
    required this.jenisKuponId,
    required this.tanggalTransaksi,
    required this.jumlahDiambil,
    this.keterangan,
    this.createdAt,
    this.isDeleted = 0,
    this.deletedAt,
    this.status = 'completed',
  });
}

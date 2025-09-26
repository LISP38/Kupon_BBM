class TransaksiEntity {
  final int purchasingId;
  final int kuponId;
  final String tanggalTransaksi;
  final double jumlahDiambil;
  final String? createdAt;
  final int isDeleted;
  final String? deletedAt;

  const TransaksiEntity({
    required this.purchasingId,
    required this.kuponId,
    required this.tanggalTransaksi,
    required this.jumlahDiambil,
    this.createdAt,
    this.isDeleted = 0,
    this.deletedAt,
  });
}

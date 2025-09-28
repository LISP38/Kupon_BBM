class TransaksiEntity {
  final int transaksiId;
  final int kuponId;
  final String nomorKupon;
  final String namaSatker;
  final int jenisBbmId;
  final String tanggalTransaksi;
  final double jumlahLiter;
  final String createdAt;
  final String? updatedAt;
  final int isDeleted;
  final int? jumlahDiambil;
  final String? status;
  final String? kuponCreatedAt;
  final String? kuponExpiredAt;

  String get jenisBbm => jenisBbmId.toString();

  const TransaksiEntity({
    required this.transaksiId,
    required this.kuponId,
    required this.nomorKupon,
    required this.namaSatker,
    required this.jenisBbmId,
    required this.tanggalTransaksi,
    required this.jumlahLiter,
    required this.createdAt,
    this.updatedAt,
    this.isDeleted = 0,
    this.jumlahDiambil = 0,
    this.status = 'Aktif',
    this.kuponCreatedAt,
    this.kuponExpiredAt,
  });
}

import '../../domain/entities/transaksi_entity.dart';

class TransaksiModel extends TransaksiEntity {
  const TransaksiModel({
    required super.transaksiId,
    required super.kuponId,
    required super.nomorKupon,
    required super.namaSatker,
    required super.jenisBbmId,
    required super.tanggalTransaksi,
    required super.jumlahLiter,
    required super.createdAt,
    super.updatedAt,
    super.isDeleted = 0,
    super.jumlahDiambil = 0,
    super.status = 'Aktif',
    super.kuponCreatedAt,
    super.kuponExpiredAt,
  });

  factory TransaksiModel.fromMap(Map<String, dynamic> map) {
    return TransaksiModel(
      transaksiId: map['transaksi_id'] as int,
      kuponId: map['kupon_id'] as int,
      nomorKupon: (map['kupon_nomor'] ?? map['nomor_kupon']) as String,
      namaSatker: (map['kupon_satker'] ?? map['nama_satker']) as String,
      jenisBbmId: (map['kupon_jenis_bbm'] ?? map['jenis_bbm_id']) as int,
      tanggalTransaksi: map['tanggal_transaksi'] as String,
      jumlahLiter: (map['jumlah_liter'] as num).toDouble(),
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String? ?? map['created_at'] as String,
      isDeleted: map['is_deleted'] as int? ?? 0,
      jumlahDiambil: map['jumlah_diambil'] as int? ?? 0,
      status: map['status'] as String? ?? 'pending',
      kuponCreatedAt: map['kupon_created_at'] as String?,
      kuponExpiredAt: map['kupon_expired_at'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'transaksi_id': transaksiId,
      'kupon_id': kuponId,
      'jumlah_liter': jumlahLiter,
      'tanggal_transaksi': tanggalTransaksi,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_deleted': isDeleted,
      'jumlah_diambil': jumlahDiambil,
      'status': status,
    };
  }
}

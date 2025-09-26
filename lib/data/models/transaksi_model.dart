import '../../domain/entities/transaksi_entity.dart';

class TransaksiModel extends TransaksiEntity {
  const TransaksiModel({
    required super.purchasingId,
    required super.kuponId,
    required super.tanggalTransaksi,
    required super.jumlahDiambil,
    super.createdAt,
    super.isDeleted = 0,
    super.deletedAt,
  });

  factory TransaksiModel.fromMap(Map<String, dynamic> map) {
    return TransaksiModel(
      purchasingId: map['purchasing_id'] as int,
      kuponId: map['kupon_id'] as int,
      tanggalTransaksi: map['tanggal_transaksi'] as String,
      jumlahDiambil: (map['jumlah_diambil'] as num).toDouble(),
      createdAt: map['created_at'] as String?,
      isDeleted: map['is_deleted'] as int? ?? 0,
      deletedAt: map['deleted_at'] as String?,
    );
  }

  get transaksiId => null;

  Map<String, dynamic> toMap() {
    return {
      'purchasing_id': purchasingId,
      'kupon_id': kuponId,
      'tanggal_transaksi': tanggalTransaksi,
      'jumlah_diambil': jumlahDiambil,
      'created_at': createdAt,
      'is_deleted': isDeleted,
      'deleted_at': deletedAt,
    };
  }
}

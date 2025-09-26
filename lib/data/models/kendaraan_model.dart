import '../../domain/entities/kendaraan_entity.dart';

class KendaraanModel extends KendaraanEntity {
  const KendaraanModel({
    required super.kendaraanId,
    required super.satkerId,
    required super.jenisRanmor,
    required super.noPolKode,
    required super.noPolNomor,
    super.statusAktif = 1,
    super.createdAt,
  });

  factory KendaraanModel.fromMap(Map<String, dynamic> map) {
    return KendaraanModel(
      kendaraanId: map['kendaraan_id'] as int,
      satkerId: map['satker_id'] as int,
      jenisRanmor: map['jenis_ranmor'] as String,
      noPolKode: map['no_pol_kode'] as String,
      noPolNomor: map['no_pol_nomor'] as String,
      statusAktif: map['status_aktif'] as int? ?? 1,
      createdAt: map['created_at'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'satker_id': satkerId,
      'jenis_ranmor': jenisRanmor,
      'no_pol_kode': noPolKode,
      'no_pol_nomor': noPolNomor,
      'status_aktif': statusAktif,
      'created_at': createdAt,
    };
    // Hanya sertakan kendaraan_id jika > 0 (untuk update, bukan insert baru)
    if (kendaraanId > 0) {
      map['kendaraan_id'] = kendaraanId;
    }
    return map;
  }
}

import '../../domain/entities/kupon_entity.dart';

class KuponModel extends KuponEntity {
  const KuponModel({
    required super.kuponId,
    required super.nomorKupon,
    required super.kendaraanId,
    required super.jenisBbmId,
    required super.jenisKuponId,
    required super.bulanTerbit,
    required super.tahunTerbit,
    required super.tanggalMulai,
    required super.tanggalSampai,
    required super.kuotaAwal,
    required super.kuotaSisa,
    required super.namaSatker,
    super.status = 'Aktif',
    super.createdAt,
    super.updatedAt,
    super.isDeleted = 0,
  });

  factory KuponModel.fromMap(Map<String, dynamic> map) {
    return KuponModel(
      kuponId: map['kupon_id'] as int,
      nomorKupon: map['nomor_kupon'] as String,
      kendaraanId: map['kendaraan_id'] as int,
      jenisBbmId: map['jenis_bbm_id'] as int,
      jenisKuponId: map['jenis_kupon_id'] as int,
      bulanTerbit: map['bulan_terbit'] as int,
      tahunTerbit: map['tahun_terbit'] as int,
      tanggalMulai: map['tanggal_mulai'] as String,
      tanggalSampai: map['tanggal_sampai'] as String,
      kuotaAwal: (map['kuota_awal'] as num).toDouble(),
      kuotaSisa: (map['kuota_sisa'] as num).toDouble(),
  namaSatker: map['nama_satker'] as String? ?? map['satker'] as String? ?? '',
      status: map['status'] as String? ?? 'Aktif',
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
      isDeleted: map['is_deleted'] as int? ?? 0,
    );
  }

  KuponModel copyWith({
    int? kuponId,
    String? nomorKupon,
    int? kendaraanId,
    int? jenisBbmId,
    int? jenisKuponId,
    int? bulanTerbit,
    int? tahunTerbit,
    String? tanggalMulai,
    String? tanggalSampai,
    double? kuotaAwal,
    double? kuotaSisa,
    String? namaSatker,
    String? status,
    String? createdAt,
    String? updatedAt,
    int? isDeleted,
  }) {
    return KuponModel(
      kuponId: kuponId ?? this.kuponId,
      nomorKupon: nomorKupon ?? this.nomorKupon,
      kendaraanId: kendaraanId ?? this.kendaraanId,
      jenisBbmId: jenisBbmId ?? this.jenisBbmId,
      jenisKuponId: jenisKuponId ?? this.jenisKuponId,
      bulanTerbit: bulanTerbit ?? this.bulanTerbit,
      tahunTerbit: tahunTerbit ?? this.tahunTerbit,
      tanggalMulai: tanggalMulai ?? this.tanggalMulai,
      tanggalSampai: tanggalSampai ?? this.tanggalSampai,
      kuotaAwal: kuotaAwal ?? this.kuotaAwal,
      kuotaSisa: kuotaSisa ?? this.kuotaSisa,
      namaSatker: namaSatker ?? this.namaSatker,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'nomor_kupon': nomorKupon,
      'kendaraan_id': kendaraanId,
      'jenis_bbm_id': jenisBbmId,
      'jenis_kupon_id': jenisKuponId,
      'bulan_terbit': bulanTerbit,
      'tahun_terbit': tahunTerbit,
      'tanggal_mulai': tanggalMulai,
      'tanggal_sampai': tanggalSampai,
      'kuota_awal': kuotaAwal,
      'kuota_sisa': kuotaSisa,
  'nama_satker': namaSatker,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_deleted': isDeleted,
    };
    // Hanya sertakan kupon_id jika > 0 (untuk update, bukan insert baru)
    if (kuponId > 0) {
      map['kupon_id'] = kuponId;
    }
    return map;
  }
}

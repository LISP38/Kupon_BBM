import '../../domain/entities/satker_entity.dart';

class SatkerModel extends SatkerEntity {
  const SatkerModel({required super.satkerId, required super.namaSatker});

  factory SatkerModel.fromMap(Map<String, dynamic> map) {
    return SatkerModel(
      satkerId: map['satker_id'] as int,
      namaSatker: map['nama_satker'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {'satker_id': satkerId, 'nama_satker': namaSatker};
  }
}

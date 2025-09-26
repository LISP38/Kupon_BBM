import '../../domain/entities/satker_entity.dart';

class SatkerModel extends SatkerEntity {
  const SatkerModel({
    required super.satkerId,
    required super.namaSatker,
  });

  factory SatkerModel.fromMap(Map<String, dynamic> map) {
    return SatkerModel(
      satkerId: map['id'] as int,
      namaSatker: map['nama'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': satkerId,
      'nama': namaSatker,
    };
  }
}
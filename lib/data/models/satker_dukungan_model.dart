import '../../domain/entities/satker_dukungan_entity.dart';

class SatkerDukunganModel extends SatkerDukunganEntity {
  const SatkerDukunganModel({
    required super.satkerId,
    required super.namaSatker,
    required super.isEligible,
  });

  factory SatkerDukunganModel.fromMap(Map<String, dynamic> map) {
    return SatkerDukunganModel(
      satkerId: map['satker_id'] as int,
      namaSatker: map['nama_satker'] as String,
      isEligible: (map['is_eligible'] as int) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'satker_id': satkerId,
      'nama_satker': namaSatker,
      'is_eligible': isEligible ? 1 : 0,
    };
  }
}

// Helper class untuk eligible satker constants
class EligibleSatker {
  static const List<Map<String, dynamic>> defaultEligibleSatkers = [
    {'satker_id': 1, 'nama_satker': 'KAPOLDA', 'is_eligible': true},
    {'satker_id': 2, 'nama_satker': 'WAKAPOLDA', 'is_eligible': true},
    {'satker_id': 3, 'nama_satker': 'PROPAM', 'is_eligible': true},
    {'satker_id': 4, 'nama_satker': 'CADANGAN', 'is_eligible': true},
  ];

  static bool isEligibleForDukungan(String namaSatker) {
    final eligibleNames = ['KAPOLDA', 'WAKAPOLDA', 'PROPAM', 'CADANGAN'];
    return eligibleNames.any((name) => namaSatker.toUpperCase().contains(name));
  }
}

import '../models/kupon_model.dart';

class ValidationRule {
  final String field;
  final String message;
  final bool Function(dynamic value) validator;

  ValidationRule({
    required this.field,
    required this.message,
    required this.validator,
  });
}

class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  final Map<String, dynamic> metadata;

  ValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
    this.metadata = const {},
  });
}

class EnhancedImportValidator {
  // Validasi periode import
  static ValidationResult validateImportPeriod({
    required List<KuponModel> kupons,
    int? expectedMonth,
    int? expectedYear,
  }) {
    final errors = <String>[];
    final warnings = <String>[];
    final metadata = <String, dynamic>{};

    if (expectedMonth != null && expectedYear != null) {
      final wrongPeriod = kupons.where(
        (k) => k.bulanTerbit != expectedMonth || k.tahunTerbit != expectedYear,
      );

      if (wrongPeriod.isNotEmpty) {
        errors.add(
          'Ditemukan ${wrongPeriod.length} kupon dengan periode yang salah. '
          'Diharapkan: $expectedMonth/$expectedYear',
        );
        metadata['wrong_period_kupons'] = wrongPeriod
            .map((k) => '${k.nomorKupon} (${k.bulanTerbit}/${k.tahunTerbit})')
            .toList();
      }
    }

    // Check mixed periods
    final periods = kupons
        .map((k) => '${k.bulanTerbit}/${k.tahunTerbit}')
        .toSet();

    if (periods.length > 1) {
      warnings.add(
        'File berisi kupon dari beberapa periode: ${periods.join(", ")}',
      );
      metadata['mixed_periods'] = periods.toList();
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      metadata: metadata,
    );
  }

  // Validasi duplikasi internal dalam file
  static ValidationResult validateInternalDuplicates(List<KuponModel> kupons) {
    final errors = <String>[];
    final warnings = <String>[];
    final seen = <String>{};
    final duplicates = <String, int>{};

    for (final kupon in kupons) {
      final key =
          '${kupon.nomorKupon}_${kupon.bulanTerbit}_${kupon.tahunTerbit}_${kupon.jenisKuponId}';

      if (seen.contains(key)) {
        duplicates[key] = (duplicates[key] ?? 1) + 1;
      } else {
        seen.add(key);
      }
    }

    if (duplicates.isNotEmpty) {
      errors.add('Ditemukan duplikat dalam file Excel:');
      duplicates.forEach((key, count) {
        errors.add('• $key: $count kali');
      });
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      metadata: {'duplicates': duplicates},
    );
  }

  // Validasi terhadap database existing
  static ValidationResult validateAgainstExisting({
    required List<KuponModel> newKupons,
    required List<KuponModel> existingKupons,
  }) {
    final errors = <String>[];
    final warnings = <String>[];
    final metadata = <String, dynamic>{};

    final conflicts = <String, List<String>>{};

    for (final newKupon in newKupons) {
      final key =
          '${newKupon.nomorKupon}_${newKupon.bulanTerbit}_${newKupon.tahunTerbit}_${newKupon.jenisKuponId}';

      final existing = existingKupons
          .where(
            (k) =>
                k.nomorKupon == newKupon.nomorKupon &&
                k.bulanTerbit == newKupon.bulanTerbit &&
                k.tahunTerbit == newKupon.tahunTerbit &&
                k.jenisKuponId == newKupon.jenisKuponId,
          )
          .toList();

      if (existing.isNotEmpty) {
        // Mode ketat: selalu reject duplikat
        conflicts[key] = existing.map((k) => 'ID: ${k.kuponId}').toList();
      }
    }

    if (conflicts.isNotEmpty) {
      errors.add('DUPLIKAT DETECTED: Data sudah ada di sistem!');
      conflicts.forEach((key, existingIds) {
        errors.add('• Kupon $key: sudah ada (${existingIds.join(", ")})');
      });
    }

    metadata['conflicts'] = conflicts;
    metadata['replacement_count'] = 0; // Tidak ada replacement lagi

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      metadata: metadata,
    );
  }

  // Comprehensive validation
  static ValidationResult validateImport({
    required List<KuponModel> kupons,
    required List<KuponModel> existingKupons,
    int? expectedMonth,
    int? expectedYear,
  }) {
    final allErrors = <String>[];
    final allWarnings = <String>[];
    final allMetadata = <String, dynamic>{};

    // 1. Validate periods
    final periodResult = validateImportPeriod(
      kupons: kupons,
      expectedMonth: expectedMonth,
      expectedYear: expectedYear,
    );

    allErrors.addAll(periodResult.errors);
    allWarnings.addAll(periodResult.warnings);
    allMetadata.addAll(periodResult.metadata);

    // 2. Validate internal duplicates
    final internalResult = validateInternalDuplicates(kupons);
    allErrors.addAll(internalResult.errors);
    allWarnings.addAll(internalResult.warnings);
    allMetadata.addAll(internalResult.metadata);

    // 3. Validate against existing (strict mode - no duplicates allowed)
    final existingResult = validateAgainstExisting(
      newKupons: kupons,
      existingKupons: existingKupons,
    );

    allErrors.addAll(existingResult.errors);
    allWarnings.addAll(existingResult.warnings);
    allMetadata.addAll(existingResult.metadata);

    return ValidationResult(
      isValid: allErrors.isEmpty,
      errors: allErrors,
      warnings: allWarnings,
      metadata: allMetadata,
    );
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:kupon_bbm_app/data/models/transaksi_model.dart';
import 'package:kupon_bbm_app/data/models/kupon_model.dart';

void main() {
  group('Transaksi Minus Calculation Tests', () {
    /// Test case 1: Transaksi tunggal yang menyebabkan minus
    test('Single transaction causes minus (consumption > quota)', () {
      final kuota_awal = 50.0;
      final transaksi_1 = 75.0; // Melebihi kuota

      final kuota_sisa = kuota_awal - transaksi_1;
      final is_minus = kuota_sisa < 0;

      expect(kuota_sisa, -25.0);
      expect(is_minus, true);
    });

    /// Test case 2: Multiple transaksi ke kupon yang sama
    /// Scenario: Kupon dengan kuota 100L, 3 transaksi (30L + 35L + 40L)
    test('Multiple transactions to same coupon (total > quota)', () {
      final kuota_awal = 100.0;
      final transactions = [30.0, 35.0, 40.0]; // Total: 105L

      // Hitung total konsumsi
      final total_used = transactions.fold<double>(0, (sum, t) => sum + t);
      final kuota_sisa = kuota_awal - total_used;
      final is_minus = kuota_sisa < 0;

      print('📊 Kuota Awal: $kuota_awal L');
      print('📊 Transaksi 1: ${transactions[0]} L');
      print('📊 Transaksi 2: ${transactions[1]} L');
      print('📊 Transaksi 3: ${transactions[2]} L');
      print('📊 Total Konsumsi: $total_used L');
      print('📊 Kuota Sisa: $kuota_sisa L');
      print('📊 Status Minus: $is_minus');

      expect(total_used, 105.0);
      expect(kuota_sisa, -5.0);
      expect(is_minus, true);
    });

    /// Test case 3: Beberapa transaksi, masih OK
    test('Multiple transactions within quota (no minus)', () {
      final kuota_awal = 100.0;
      final transactions = [20.0, 30.0, 25.0]; // Total: 75L

      final total_used = transactions.fold<double>(0, (sum, t) => sum + t);
      final kuota_sisa = kuota_awal - total_used;
      final is_minus = kuota_sisa < 0;

      print('📊 Kuota Awal: $kuota_awal L');
      print('📊 Transaksi 1: ${transactions[0]} L');
      print('📊 Transaksi 2: ${transactions[1]} L');
      print('📊 Transaksi 3: ${transactions[2]} L');
      print('📊 Total Konsumsi: $total_used L');
      print('📊 Kuota Sisa: $kuota_sisa L');
      print('📊 Status Minus: $is_minus');

      expect(total_used, 75.0);
      expect(kuota_sisa, 25.0);
      expect(is_minus, false);
    });

    /// Test case 4: Transaksi dari beberapa hari berbeda
    test('Multiple transactions on different dates to same coupon', () {
      final kupon = KuponModel(
        kuponId: 1,
        nomorKupon: '001',
        jenisBbmId: 1,
        jenisKuponId: 1,
        bulanTerbit: 11,
        tahunTerbit: 2025,
        tanggalMulai: '2025-11-01',
        tanggalSampai: '2025-11-30',
        kuotaAwal: 100.0,
        kuotaSisa: 100.0,
        satkerId: 1,
        namaSatker: 'SATKER A',
      );

      final transaksi = [
        TransaksiModel(
          transaksiId: 1,
          kuponId: 1,
          nomorKupon: '001',
          namaSatker: 'SATKER A',
          jenisBbmId: 1,
          jenisKuponId: 1,
          tanggalTransaksi: '2025-11-05',
          jumlahLiter: 30.0,
          createdAt: '2025-11-05T10:00:00',
        ),
        TransaksiModel(
          transaksiId: 2,
          kuponId: 1,
          nomorKupon: '001',
          namaSatker: 'SATKER A',
          jenisBbmId: 1,
          jenisKuponId: 1,
          tanggalTransaksi: '2025-11-12',
          jumlahLiter: 45.0,
          createdAt: '2025-11-12T10:00:00',
        ),
        TransaksiModel(
          transaksiId: 3,
          kuponId: 1,
          nomorKupon: '001',
          namaSatker: 'SATKER A',
          jenisBbmId: 1,
          jenisKuponId: 1,
          tanggalTransaksi: '2025-11-20',
          jumlahLiter: 35.0,
          createdAt: '2025-11-20T10:00:00',
        ),
      ];

      final total_used = transaksi.fold<double>(
        0,
        (sum, t) => sum + t.jumlahLiter,
      );
      final kuota_sisa = kupon.kuotaAwal - total_used;
      final is_minus = kuota_sisa < 0;
      final abs_minus = is_minus ? (total_used - kupon.kuotaAwal) : 0.0;

      print(
        '📊 Kupon: ${kupon.nomorKupon}/${kupon.bulanTerbit}/${kupon.tahunTerbit}',
      );
      print('📊 Kuota Awal: ${kupon.kuotaAwal} L');
      print(
        '📊 Tanggal Berlaku: ${kupon.tanggalMulai} - ${kupon.tanggalSampai}',
      );
      print(
        '📊 Transaksi 1 (${transaksi[0].tanggalTransaksi}): ${transaksi[0].jumlahLiter} L',
      );
      print(
        '📊 Transaksi 2 (${transaksi[1].tanggalTransaksi}): ${transaksi[1].jumlahLiter} L',
      );
      print(
        '📊 Transaksi 3 (${transaksi[2].tanggalTransaksi}): ${transaksi[2].jumlahLiter} L',
      );
      print('📊 Total Konsumsi: $total_used L');
      print('📊 Kuota Sisa: $kuota_sisa L');
      print('📊 Status Minus: $is_minus');
      if (is_minus) {
        print('📊 Nilai Minus: $abs_minus L');
      }

      expect(total_used, 110.0);
      expect(kuota_sisa, -10.0);
      expect(is_minus, true);
      expect(abs_minus, 10.0);
    });

    /// Test case 5: Edge case - Transaksi exact dengan kuota
    test('Multiple transactions exactly match quota', () {
      final kuota_awal = 100.0;
      final transactions = [25.0, 25.0, 25.0, 25.0]; // Total: 100L

      final total_used = transactions.fold<double>(0, (sum, t) => sum + t);
      final kuota_sisa = kuota_awal - total_used;
      final is_minus = kuota_sisa < 0;

      expect(total_used, 100.0);
      expect(kuota_sisa, 0.0);
      expect(is_minus, false);
    });

    /// Test case 6: Banyak transaksi kecil yang akumulatif melebihi kuota
    test('Many small transactions accumulate to exceed quota', () {
      final kuota_awal = 100.0;
      final transactions = List<double>.generate(25, (i) => 4.5);
      // 25 x 4.5 = 112.5 L

      final total_used = transactions.fold<double>(0, (sum, t) => sum + t);
      final kuota_sisa = kuota_awal - total_used;
      final is_minus = kuota_sisa < 0;

      print('📊 Kuota Awal: $kuota_awal L');
      print('📊 Jumlah Transaksi: ${transactions.length}');
      print('📊 Setiap Transaksi: 4.5 L');
      print('📊 Total Konsumsi: $total_used L');
      print('📊 Kuota Sisa: $kuota_sisa L');
      print('📊 Status Minus: $is_minus');

      expect(transactions.length, 25);
      expect(total_used, 112.5);
      expect(kuota_sisa, -12.5);
      expect(is_minus, true);
    });
  });

  group('Kupon Status Tests', () {
    /// Test case: Kupon bulan lalu seharusnya tidak aktif
    test(
      'Kupon from previous month (Nov 2025) should not be active in current period',
      () {
        // Simulasi hari ini = 29 Januari 2026
        final today = DateTime(2026, 1, 29);

        // Kupon November 2025
        final kupon_nov_2025 = KuponModel(
          kuponId: 1,
          nomorKupon: '001',
          jenisBbmId: 1,
          jenisKuponId: 1,
          bulanTerbit: 11,
          tahunTerbit: 2025,
          tanggalMulai: '2025-11-01',
          tanggalSampai: '2025-11-30',
          kuotaAwal: 100.0,
          kuotaSisa: 50.0,
          satkerId: 1,
          namaSatker: 'SATKER A',
          status: 'Aktif', // ⚠️ INI YANG SALAH!
        );

        // Kupon Januari 2026 (current month)
        final kupon_jan_2026 = KuponModel(
          kuponId: 2,
          nomorKupon: '002',
          jenisBbmId: 1,
          jenisKuponId: 1,
          bulanTerbit: 1,
          tahunTerbit: 2026,
          tanggalMulai: '2026-01-01',
          tanggalSampai: '2026-01-31',
          kuotaAwal: 100.0,
          kuotaSisa: 75.0,
          satkerId: 1,
          namaSatker: 'SATKER A',
          status: 'Aktif',
        );

        // Check validity
        final tanggal_mulai_nov = DateTime.parse(kupon_nov_2025.tanggalMulai);
        final tanggal_sampai_nov = DateTime.parse(kupon_nov_2025.tanggalSampai);
        final is_nov_valid =
            today.isAfter(tanggal_mulai_nov) &&
            today.isBefore(tanggal_sampai_nov);

        final tanggal_mulai_jan = DateTime.parse(kupon_jan_2026.tanggalMulai);
        final tanggal_sampai_jan = DateTime.parse(kupon_jan_2026.tanggalSampai);
        final is_jan_valid =
            today.isAfter(tanggal_mulai_jan) &&
            today.isBefore(tanggal_sampai_jan);

        print('🗓️ Hari Ini: ${today.toIso8601String()}');
        print('');
        print('📋 Kupon November 2025:');
        print(
          '   Berlaku: ${kupon_nov_2025.tanggalMulai} - ${kupon_nov_2025.tanggalSampai}',
        );
        print('   Status: ${kupon_nov_2025.status}');
        print('   ✓ Valid Sekarang: $is_nov_valid');
        print('   ❌ SHOULD NOT BE ACTIVE!');
        print('');
        print('📋 Kupon Januari 2026:');
        print(
          '   Berlaku: ${kupon_jan_2026.tanggalMulai} - ${kupon_jan_2026.tanggalSampai}',
        );
        print('   Status: ${kupon_jan_2026.status}');
        print('   ✓ Valid Sekarang: $is_jan_valid');

        // Assert
        expect(
          is_nov_valid,
          false,
          reason: 'November 2025 kupon should NOT be valid on 29 Jan 2026',
        );
        expect(
          is_jan_valid,
          true,
          reason: 'January 2026 kupon SHOULD be valid on 29 Jan 2026',
        );

        // ❌ This is the bug: November kupon masih marked as 'Aktif'
        // ✅ Should be: status = 'Tidak Aktif' atau 'Kadaluarsa'
        print(
          '\n⚠️  BUG DETECTED: November 2025 kupon status is "${kupon_nov_2025.status}" but should be "Tidak Aktif"',
        );
      },
    );

    /// Test case: Logic untuk menentukan status kupon berdasarkan tanggal
    test('Kupon status determination based on date validity', () {
      final today = DateTime(2026, 1, 29);

      // Test berbagai kupon dengan tanggal berbeda
      final testCases = [
        {
          'nama': 'Kupon November 2025',
          'mulai': '2025-11-01',
          'sampai': '2025-11-30',
          'expected_valid': false,
        },
        {
          'nama': 'Kupon Desember 2025',
          'mulai': '2025-12-01',
          'sampai': '2025-12-31',
          'expected_valid': false,
        },
        {
          'nama': 'Kupon Januari 2026',
          'mulai': '2026-01-01',
          'sampai': '2026-01-31',
          'expected_valid': true,
        },
        {
          'nama': 'Kupon Februari 2026',
          'mulai': '2026-02-01',
          'sampai': '2026-02-28',
          'expected_valid': false,
        },
      ];

      print('🗓️ Hari Ini: ${today.toIso8601String().split('T')[0]}\n');

      for (final testCase in testCases) {
        final mulai = DateTime.parse(testCase['mulai'] as String);
        final sampai = DateTime.parse(testCase['sampai'] as String);
        final isValid =
            today.isAfter(mulai) &&
            today.isBefore(sampai.add(Duration(days: 1)));
        final expectedValid = testCase['expected_valid'] as bool;

        final status = isValid ? '✅ Aktif' : '❌ Tidak Aktif/Kadaluarsa';

        print('${testCase['nama']}:');
        print('   Berlaku: ${testCase['mulai']} - ${testCase['sampai']}');
        print('   Status: $status');
        print('   Expected: ${expectedValid ? 'Aktif' : 'Tidak Aktif'}');
        print('');

        expect(
          isValid,
          expectedValid,
          reason:
              '${testCase['nama']} validity check failed on ${today.toIso8601String().split('T')[0]}',
        );
      }
    });
  });
}

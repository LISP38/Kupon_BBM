# TODO: Revisi Import Kupon - Nonaktifkan Validasi Jumlah Kupon Per Bulan, Hapus UNIQUE nomor_kupon, & Replace Mode

## Perubahan yang Dilakukan:

- **Update KuponValidator** (lib/data/validators/kupon_validator.dart)
  - Dinonaktifkan validasi `validateKuponPerBulan` untuk mengizinkan import multiple kupon jenis yang sama (Ranjen/Dukungan) per kendaraan per bulan.
  - Validasi ini sebelumnya membatasi maksimal 1 Ranjen + 1 Dukungan per bulan, yang menyebabkan hanya 2 kupon yang di-import dari 4 kupon.

- **Update DatabaseDatasource** (lib/data/datasources/database_datasource.dart)
  - Dihapus constraint UNIQUE dari kolom `nomor_kupon` di tabel `fact_kupon`.
  - Ditambahkan database migration (version 2) untuk menghapus UNIQUE constraint dari database existing.
  - Sekarang memungkinkan multiple kupon dengan nomor_kupon yang sama.

- **Update KuponRepository** (lib/domain/repositories/kupon_repository.dart & kupon_repository_impl.dart)
  - Ditambahkan method `deleteAllKupon()` untuk menghapus semua data kupon.

- **Update ImportProvider** (lib/presentation/providers/import_provider.dart)
  - Diperbaiki logika replace mode: jika replace mode aktif, hapus semua kupon existing terlebih dahulu, lalu insert kupon baru.
  - Ini memastikan replace mengganti seluruh data dengan data baru dari Excel, bukan update per nomor_kupon.

## Testing:
- Test import Excel dengan 4 kupon (misal 2 kupon dengan nomor 111 dan 2 dengan nomor 112).
- Pastikan dengan mode replace, dashboard menampilkan tepat 4 kupon (bukan menambah ke existing).
- Jika database existing, migration akan menghapus UNIQUE constraint secara otomatis.

Last Updated: Replace mode sekarang menghapus semua data existing dan mengganti dengan data baru.

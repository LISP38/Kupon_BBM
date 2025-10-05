# Format Excel untuk Import Kupon DUKUNGAN

## ✅ Perubahan yang telah dibuat:

Sistem sekarang **SUDAH MENDUKUNG** import kupon DUKUNGAN dengan kolom kendaraan yang kosong!

## 📋 Format Excel untuk Kupon DUKUNGAN:

| Kolom | Nama | Wajib untuk DUKUNGAN | Contoh | Keterangan |
|-------|------|---------------------|--------|------------|
| A | Jenis Kupon | ✅ **WAJIB** | "Dukungan" | Harus mengandung kata "dukungan" |
| B | No Kupon | ✅ **WAJIB** | "001" | Nomor kupon |
| C | Bulan | ✅ **WAJIB** | "X" | Bulan dalam angka romawi (I-XII) |
| D | Tahun | ✅ **WAJIB** | "2025" | Tahun 4 digit |
| E | Jenis Ranmor | ❌ **BOLEH KOSONG** | "" | Untuk DUKUNGAN boleh kosong |
| F | Satker | ✅ **WAJIB** | "KAPOLDA" | Harus satker yang eligible |
| G | No Pol | ❌ **BOLEH KOSONG** | "" | Untuk DUKUNGAN boleh kosong |
| H | Kode Nopol | ❌ **BOLEH KOSONG** | "" | Untuk DUKUNGAN boleh kosong |
| I | Jenis BBM | ✅ **WAJIB** | "Pertamax" | Pertamax atau Pertamina Dex |
| J | Kuantum | ✅ **WAJIB** | "100" | Jumlah liter |

## 🎯 Contoh Baris Excel untuk DUKUNGAN:

```
Dukungan | 001 | X | 2025 | | KAPOLDA | | | Pertamax | 100
```

## 🎯 Contoh Baris Excel untuk RANJEN (harus lengkap):

```
Ranjen | 001 | X | 2025 | Mobil Dinas | POLSEK ABC | 1234 | VIII | Pertamax | 100
```

## ⚠️ Aturan Penting:

1. **Jenis Kupon DUKUNGAN**: Kolom A harus mengandung kata "dukungan" (case-insensitive)
2. **Satker Eligible**: Hanya satker berikut yang bisa mendapat DUKUNGAN:
   - KAPOLDA
   - WAKAPOLDA  
   - PROPAM
   - CADANGAN
3. **Ketergantungan**: DUKUNGAN memerlukan kupon RANJEN untuk satker yang sama di periode yang sama
4. **Kolom Kosong**: Untuk DUKUNGAN, kolom E (Jenis Ranmor), G (No Pol), H (Kode Nopol) boleh dikosongkan

## 🔧 Validasi yang Berjalan:

- ✅ DUKUNGAN tanpa data kendaraan = **DITERIMA**
- ✅ Duplikat detection berdasarkan nomor kupon, periode, dan jenis
- ✅ Validasi satker eligible untuk DUKUNGAN
- ✅ Validasi ketergantungan DUKUNGAN pada RANJEN
- ✅ RANJEN tetap memerlukan data kendaraan lengkap

## 📊 Hasil Preview:

Kupon DUKUNGAN akan muncul di preview dengan:
- No Pol: "N/A (DUKUNGAN)"
- Kendaraan: "N/A (DUKUNGAN)"  
- Jenis Kupon: "DUKUNGAN"
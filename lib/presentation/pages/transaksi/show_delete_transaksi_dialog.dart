import 'package:flutter/material.dart';
import '../../../domain/entities/transaksi_entity.dart';

Future<bool?> showDeleteTransaksiDialog({
  required BuildContext context,
  required TransaksiEntity transaksi,
}) {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Konfirmasi Hapus'),
        content: Text(
          'Apakah Anda yakin ingin menghapus transaksi ini?\n\n'
          'Nomor Kupon: ${transaksi.nomorKupon}\n'
          'Tanggal: ${transaksi.tanggalTransaksi}\n'
          'Jumlah: ${transaksi.jumlahLiter} L',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      );
    },
  );
}

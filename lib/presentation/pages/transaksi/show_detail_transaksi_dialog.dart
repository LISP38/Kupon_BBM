import 'package:flutter/material.dart';
import '../../../domain/entities/transaksi_entity.dart';
import 'package:intl/intl.dart';

String formatDateToIndonesian(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return '-';
  try {
    final date = DateTime.parse(dateStr);
    return DateFormat('dd MMMM yyyy', 'id_ID').format(date);
  } catch (e) {
    return dateStr;
  }
}

Future<void> showDetailTransaksiDialog({
  required BuildContext context,
  required TransaksiEntity transaksi,
}) {
  return showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Detail Transaksi'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow(
                'Tanggal',
                formatDateToIndonesian(transaksi.tanggalTransaksi),
              ),
              _buildDetailRow('Nomor Kupon', transaksi.nomorKupon),
              _buildDetailRow(
                'Jenis BBM',
                transaksi.jenisBbmId == 1 ? 'Pertamax' : 'Pertamina Dex',
              ),
              _buildDetailRow('Satker', transaksi.namaSatker),
              _buildDetailRow('Jumlah Liter', '${transaksi.jumlahLiter} L'),
              _buildDetailRow(
                'Tanggal Kupon Dibuat',
                formatDateToIndonesian(transaksi.kuponCreatedAt),
              ),
              _buildDetailRow(
                'Tanggal Kupon Kadaluarsa',
                formatDateToIndonesian(transaksi.kuponExpiredAt),
              ),
              _buildDetailRow(
                'Dibuat pada',
                formatDateToIndonesian(transaksi.createdAt),
              ),
              if (transaksi.updatedAt != null)
                _buildDetailRow(
                  'Diperbarui pada',
                  formatDateToIndonesian(transaksi.updatedAt),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tutup'),
          ),
        ],
      );
    },
  );
}

Widget _buildDetailRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

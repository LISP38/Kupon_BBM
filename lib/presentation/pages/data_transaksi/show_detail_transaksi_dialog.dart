import 'package:flutter/material.dart';
// import removed: '../../providers/transaksi_provider.dart';
import '../../../domain/entities/transaksi_entity.dart';

class ShowDetailTransaksiDialog extends StatelessWidget {
  final TransaksiEntity transaksi;
  const ShowDetailTransaksiDialog({Key? key, required this.transaksi}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Detail Transaksi'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow('Tanggal', transaksi.tanggalTransaksi),
          _buildDetailRow('Nomor Kupon', transaksi.nomorKupon),
          _buildDetailRow('Satker', transaksi.namaSatker),
          _buildDetailRow('Jenis BBM', transaksi.jenisBbmId.toString()),
          // 'Jenis Kupon' not available in TransaksiEntity, use placeholder or omit
          // _buildDetailRow('Jenis Kupon', transaksi.jenisKuponId.toString()),
          _buildDetailRow('Jumlah (L)', transaksi.jumlahLiter.toString()),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Tutup'),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

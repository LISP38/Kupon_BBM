import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/entities/kupon_entity.dart';
import '../../providers/transaksi_provider.dart';
import '../transaksi/show_transaksi_bbm_dialog.dart';

class DashboardActions extends StatelessWidget {
  const DashboardActions({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Transaksi BBM',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    context: context,
                    icon: Icons.local_gas_station,
                    label: 'Transaksi Pertamax',
                    color: Colors.blue,
                    jenisBbmId: 1,
                    jenisBbmName: 'Pertamax',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildActionButton(
                    context: context,
                    icon: Icons.local_gas_station,
                    label: 'Transaksi Dex',
                    color: Colors.green,
                    jenisBbmId: 2,
                    jenisBbmName: 'Pertamina Dex',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required int jenisBbmId,
    required String jenisBbmName,
  }) {
    return ElevatedButton.icon(
      onPressed: () => _handleTransaksi(context, jenisBbmId, jenisBbmName),
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Future<void> _handleTransaksi(
    BuildContext context,
    int jenisBbmId,
    String jenisBbmName,
  ) async {
    final result = await showTransaksiBBMDialog(
      context: context,
      jenisBbmId: jenisBbmId,
      jenisBbmName: jenisBbmName,
    );

    if (result != null) {
      final kupon = result['kupon'] as KuponEntity;
      final jumlahLiter = result['jumlahLiter'] as double;

      // Process the transaction
      final success = await Provider.of<TransaksiProvider>(
        context,
        listen: false,
      ).createTransaksi(kuponId: kupon.kuponId, jumlahLiter: jumlahLiter);

      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transaksi berhasil disimpan'),
              backgroundColor: Colors.green,
            ),
          );

          // Refresh data
          Provider.of<TransaksiProvider>(
            context,
            listen: false,
          ).fetchTransaksiFiltered();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal menyimpan transaksi'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

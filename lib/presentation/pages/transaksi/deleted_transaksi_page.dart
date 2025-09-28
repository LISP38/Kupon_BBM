import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/transaksi_provider.dart';
import '../../../domain/entities/transaksi_entity.dart';
import 'show_detail_transaksi_dialog.dart';

class DeletedTransaksiPage extends StatefulWidget {
  const DeletedTransaksiPage({super.key});

  @override
  State<DeletedTransaksiPage> createState() => _DeletedTransaksiPageState();
}

class _DeletedTransaksiPageState extends State<DeletedTransaksiPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TransaksiProvider>(
        context,
        listen: false,
      ).fetchDeletedTransaksi();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transaksi Terhapus')),
      body: Consumer<TransaksiProvider>(
        builder: (context, provider, child) {
          if (provider.transaksiList.isEmpty) {
            return const Center(
              child: Text('Tidak ada transaksi yang terhapus'),
            );
          }

          return ListView.builder(
            itemCount: provider.transaksiList.length,
            itemBuilder: (context, index) {
              final transaksi = provider.transaksiList[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(transaksi.nomorKupon),
                  subtitle: Text(
                    'Satker: ${transaksi.namaSatker}\n'
                    'Jumlah: ${transaksi.jumlahLiter} L\n'
                    'Tanggal: ${transaksi.tanggalTransaksi}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility),
                        onPressed: () => showDetailTransaksiDialog(
                          context: context,
                          transaksi: transaksi,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.restore),
                        onPressed: () => _restoreTransaksi(transaksi),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _restoreTransaksi(TransaksiEntity transaksi) async {
    try {
      await Provider.of<TransaksiProvider>(
        context,
        listen: false,
      ).restoreTransaksi(transaksi.transaksiId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaksi berhasil dipulihkan'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memulihkan transaksi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

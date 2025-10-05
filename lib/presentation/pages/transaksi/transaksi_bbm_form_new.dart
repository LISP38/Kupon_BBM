import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../domain/entities/transaksi_entity.dart';
import '../../../data/models/transaksi_model.dart';

class TransaksiBBMForm extends StatefulWidget {
  final int jenisBbmId;
  final String jenisBbmName;
  final bool editMode;
  final TransaksiEntity? initialData;

  const TransaksiBBMForm({
    Key? key,
    required this.jenisBbmId,
    required this.jenisBbmName,
    this.editMode = false,
    this.initialData,
  }) : super(key: key);

  @override
  State<TransaksiBBMForm> createState() => _TransaksiBBMFormState();
}

class _TransaksiBBMFormState extends State<TransaksiBBMForm> {
  final _formKey = GlobalKey<FormState>();
  final _literController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.editMode && widget.initialData != null) {
      _literController.text = widget.initialData!.jumlahLiter.toString();
    }
  }

  @override
  void dispose() {
    _literController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Jenis BBM (display only)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_gas_station),
                const SizedBox(width: 8),
                Text(
                  'Jenis BBM: ${widget.jenisBbmName}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Input Liter
          TextFormField(
            controller: _literController,
            decoration: const InputDecoration(
              labelText: 'Jumlah Liter yang Diambil',
              border: OutlineInputBorder(),
              suffixText: 'Liter',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Jumlah liter harus diisi';
              }
              final liter = double.tryParse(value);
              if (liter == null) {
                return 'Format jumlah tidak valid';
              }
              if (liter <= 0) {
                return 'Jumlah harus lebih dari 0';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Submit Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  if (widget.editMode && widget.initialData != null) {
                    final updatedTransaksi = TransaksiModel(
                      transaksiId: widget.initialData!.transaksiId,
                      kuponId: widget.initialData!.kuponId,
                      nomorKupon: widget.initialData!.nomorKupon,
                      namaSatker: widget.initialData!.namaSatker,
                      jenisBbmId: widget.initialData!.jenisBbmId,
                      tanggalTransaksi: widget.initialData!.tanggalTransaksi,
                      jumlahLiter: double.parse(_literController.text),
                      createdAt: widget.initialData!.createdAt,
                      updatedAt: DateTime.now().toIso8601String(),
                    );
                    Navigator.of(context).pop({'transaksi': updatedTransaksi});
                  } else {
                    Navigator.of(
                      context,
                    ).pop({'jumlahLiter': double.parse(_literController.text)});
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                widget.editMode ? 'Update Transaksi' : 'Simpan Transaksi',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

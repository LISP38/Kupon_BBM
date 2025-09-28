import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../domain/entities/kupon_entity.dart';
import '../../../domain/entities/satker_entity.dart';
import '../../providers/kupon_provider.dart';
import '../../providers/master_data_provider.dart';

class TransaksiBBMForm extends StatefulWidget {
  final int jenisBbmId;
  final String jenisBbmName;

  const TransaksiBBMForm({
    Key? key,
    required this.jenisBbmId,
    required this.jenisBbmName,
  }) : super(key: key);

  @override
  State<TransaksiBBMForm> createState() => _TransaksiBBMFormState();
}

class _TransaksiBBMFormState extends State<TransaksiBBMForm> {
  final _formKey = GlobalKey<FormState>();
  final _literController = TextEditingController();

  // Selected values
  SatkerEntity? _selectedSatker;
  KuponEntity? _selectedKupon;
  List<KuponEntity> _availableKupons = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  void _loadInitialData() {
    final masterDataProvider = Provider.of<MasterDataProvider>(
      context,
      listen: false,
    );
    masterDataProvider.fetchSatkers();

    final kuponProvider = Provider.of<KuponProvider>(context, listen: false);
    kuponProvider.fetchKupons();
  }

  void _updateAvailableKupons() {
    if (_selectedSatker == null) {
      setState(() => _availableKupons = []);
      return;
    }

    final kuponProvider = Provider.of<KuponProvider>(context, listen: false);
    setState(() {
      _availableKupons = kuponProvider.kuponList
          .where(
            (kupon) =>
                kupon.jenisBbmId == widget.jenisBbmId &&
                kupon.satkerId == _selectedSatker!.satkerId &&
                kupon.status == 'Aktif' &&
                kupon.kuotaSisa > 0,
          )
          .toList();
    });
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

          // Satker Dropdown
          Consumer<MasterDataProvider>(
            builder: (context, provider, _) {
              return DropdownButtonFormField<SatkerEntity>(
                value: _selectedSatker,
                decoration: const InputDecoration(
                  labelText: 'Pilih Satker',
                  border: OutlineInputBorder(),
                ),
                items: provider.satkerList.map((satker) {
                  return DropdownMenuItem(
                    value: satker,
                    child: Text(satker.namaSatker),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedSatker = value;
                    _selectedKupon = null;
                  });
                  _updateAvailableKupons();
                },
                validator: (value) {
                  if (value == null) return 'Pilih satker';
                  return null;
                },
              );
            },
          ),
          const SizedBox(height: 16),

          // Kupon Dropdown (only show if satker is selected)
          if (_selectedSatker != null)
            Consumer<KuponProvider>(
              builder: (context, provider, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<KuponEntity>(
                      value: _selectedKupon,
                      decoration: const InputDecoration(
                        labelText: 'Pilih Nomor Kupon',
                        border: OutlineInputBorder(),
                      ),
                      items: _availableKupons.map((kupon) {
                        return DropdownMenuItem(
                          value: kupon,
                          child: Text(
                            '${kupon.nomorKupon} (Sisa: ${kupon.kuotaSisa} L)',
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedKupon = value;
                        });
                      },
                      validator: (value) {
                        if (value == null) return 'Pilih nomor kupon';
                        return null;
                      },
                    ),
                  ],
                );
              },
            ),

          // Kuota Information
          if (_selectedKupon != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kuota Awal: ${_selectedKupon!.kuotaAwal} Liter',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sisa Kuota: ${_selectedKupon!.kuotaSisa} Liter',
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
              if (liter > _selectedKupon!.kuotaSisa) {
                return 'Jumlah melebihi sisa kuota';
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
                  // TODO: Implement transaction submission
                  // Close the dialog and return the data
                  Navigator.of(context).pop({
                    'kupon': _selectedKupon,
                    'jumlahLiter': double.parse(_literController.text),
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Simpan Transaksi',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

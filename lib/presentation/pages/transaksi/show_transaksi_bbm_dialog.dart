import 'package:flutter/material.dart';
import 'package:kupon_bbm_app/domain/entities/transaksi_entity.dart';
import 'transaksi_bbm_form_new.dart';

Future<Map<String, dynamic>?> showTransaksiBBMDialog({
  required BuildContext context,
  required int jenisBbmId,
  required String jenisBbmName,
  bool editMode = false,
  TransaksiEntity? initialData,
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    editMode
                        ? 'Edit Transaksi BBM - $jenisBbmName'
                        : 'Transaksi BBM - $jenisBbmName',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),

              // Form in Scrollable Container
              Flexible(
                child: SingleChildScrollView(
                  child: TransaksiBBMForm(
                    jenisBbmId: jenisBbmId,
                    jenisBbmName: jenisBbmName,
                    editMode: editMode,
                    initialData: initialData,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

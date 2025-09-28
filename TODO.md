# TODO: Restructure Dashboard Layout

## Tasks
- [ ] Update imports in dashboard_page.dart (add Autocomplete if needed)
- [ ] Update initState and didChangeDependencies to fetch kupons, kendaraans, transaksi, and kuponMinus
- [ ] Modify _buildFilterSection to only include Hari and Bulan dropdowns with Cari and Reset buttons
- [ ] Add new _buildAddTransactionButtons method for Pertamax and Dex add buttons
- [ ] Replace _buildMasterKuponTable with _buildTransaksiTable (adapted from transaction_page.dart)
- [ ] Add _buildKuponMinusTable method (adapted from transaction_page.dart)
- [ ] Add _exportTransaksiToExcel method
- [ ] Add _exportKuponMinusToExcel method
- [ ] Add _showTambahTransaksiDialog method (adapted from transaction_page.dart)
- [ ] Update build() method to arrange sections: summary, filter, add buttons, transaksi table + export, minus table + export
- [ ] Remove unused code (complex filters, kupon table, old export)
- [ ] Test layout by running the app

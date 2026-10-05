import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../database_helper.dart';
import '../model/product_model.dart';

/// Produk dengan sisa stok di bawah angka ini otomatis masuk daftar PO.
const int lowStockThreshold = 5;

/// Jumlah order awal per produk (bisa diubah di layar PO).
const int defaultOrderQty = 10;

class CreatePoPage extends StatefulWidget {
  final String storeName;
  final String storeAddress;

  const CreatePoPage({
    super.key,
    required this.storeName,
    required this.storeAddress,
  });

  @override
  State<CreatePoPage> createState() => _CreatePoPageState();
}

class _CreatePoPageState extends State<CreatePoPage> {
  final _supplierController = TextEditingController();
  final _noteController = TextEditingController();
  final Map<int, TextEditingController> _qtyControllers = {};
  final Set<int> _selectedIds = {};
  List<Product> _products = [];
  bool _isLoading = true;
  late final DateTime _createdAt;
  late final String _poNumber;

  @override
  void initState() {
    super.initState();
    _createdAt = DateTime.now();
    _poNumber =
        'PO-${_createdAt.year}${_two(_createdAt.month)}${_two(_createdAt.day)}'
        '-${_two(_createdAt.hour)}${_two(_createdAt.minute)}';
    _loadProducts();
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Future<void> _loadProducts() async {
    final products = await DatabaseHelper.instance.getLowStockProducts(
      threshold: lowStockThreshold,
    );
    if (!mounted) return;
    setState(() {
      _products = products;
      for (final product in products) {
        _qtyControllers[product.id!] = TextEditingController(
          text: '$defaultOrderQty',
        );
        _selectedIds.add(product.id!);
      }
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _supplierController.dispose();
    _noteController.dispose();
    for (final controller in _qtyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  int _qtyOf(Product product) =>
      int.tryParse(_qtyControllers[product.id]?.text ?? '') ?? 0;

  List<Product> get _orderItems =>
      _products
          .where((p) => _selectedIds.contains(p.id) && _qtyOf(p) > 0)
          .toList();

  Future<Uint8List> _buildPdf() async {
    final items = _orderItems;
    final totalQty = items.fold<int>(0, (sum, p) => sum + _qtyOf(p));
    final supplier = _supplierController.text.trim();
    final note = _noteController.text.trim();

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build:
            (context) => [
              pw.Text(
                widget.storeName,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if (widget.storeAddress.isNotEmpty)
                pw.Text(
                  widget.storeAddress,
                  style: const pw.TextStyle(fontSize: 10),
                ),
              pw.SizedBox(height: 16),
              pw.Center(
                child: pw.Text(
                  'PURCHASE ORDER',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Text('No. PO     : $_poNumber'),
              pw.Text('Tanggal    : ${_formatDate(_createdAt)}'),
              pw.Text('Kepada     : ${supplier.isEmpty ? '-' : supplier}'),
              pw.SizedBox(height: 12),
              pw.TableHelper.fromTextArray(
                headers: ['No', 'Nama Produk', 'Sisa Stok', 'Jumlah Order'],
                data: [
                  for (var i = 0; i < items.length; i++)
                    [
                      '${i + 1}',
                      items[i].name,
                      '${items[i].stock}',
                      '${_qtyOf(items[i])} pack',
                    ],
                ],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                cellAlignments: {
                  0: pw.Alignment.center,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.center,
                  3: pw.Alignment.centerRight,
                },
                columnWidths: {
                  0: const pw.FixedColumnWidth(30),
                  1: const pw.FlexColumnWidth(),
                  2: const pw.FixedColumnWidth(70),
                  3: const pw.FixedColumnWidth(90),
                },
              ),
              pw.SizedBox(height: 8),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Total: ${items.length} produk, $totalQty pack',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ),
              if (note.isNotEmpty) ...[
                pw.SizedBox(height: 12),
                pw.Text('Catatan: $note'),
              ],
              pw.SizedBox(height: 40),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _signatureBox('Dipesan oleh'),
                  _signatureBox('Disetujui oleh'),
                ],
              ),
            ],
      ),
    );
    return pdf.save();
  }

  pw.Widget _signatureBox(String label) {
    return pw.Column(
      children: [
        pw.Text(label),
        pw.SizedBox(height: 50),
        pw.Text('(____________________)'),
      ],
    );
  }

  bool _validateOrder() {
    if (_orderItems.isNotEmpty) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pilih minimal 1 produk dengan jumlah order > 0.'),
      ),
    );
    return false;
  }

  Future<void> _printPdf() async {
    if (!_validateOrder()) return;
    final bytes = await _buildPdf();
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: _poNumber);
  }

  Future<void> _sharePdf() async {
    if (!_validateOrder()) return;
    final bytes = await _buildPdf();
    await Printing.sharePdf(bytes: bytes, filename: '$_poNumber.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Create PO'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body:
          _isLoading
              ? Center(
                child: CircularProgressIndicator(color: Colors.green.shade700),
              )
              : _products.isEmpty
              ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                    'Tidak ada produk dengan sisa stok di bawah '
                    '$lowStockThreshold pack/bungkus.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
              : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHeaderCard(),
                  const SizedBox(height: 16),
                  _buildItemsCard(),
                ],
              ),
      bottomNavigationBar:
          _products.isEmpty
              ? null
              : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _sharePdf,
                          icon: const Icon(Icons.share_rounded),
                          label: const Text('Bagikan'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2E7D32),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _printPdf,
                          icon: const Icon(Icons.print_rounded),
                          label: const Text('Cetak / PDF'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _poNumber,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              _formatDate(_createdAt),
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _supplierController,
              decoration: InputDecoration(
                labelText: 'Supplier (Opsional)',
                prefixIcon: const Icon(Icons.local_shipping_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Catatan (Opsional)',
                prefixIcon: const Icon(Icons.notes_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Produk stok < $lowStockThreshold (${_selectedIds.length} dipilih)',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            for (final product in _products) _buildItemRow(product),
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(Product product) {
    final selected = _selectedIds.contains(product.id);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Checkbox(
            value: selected,
            activeColor: const Color(0xFF2E7D32),
            onChanged:
                (value) => setState(() {
                  if (value == true) {
                    _selectedIds.add(product.id!);
                  } else {
                    _selectedIds.remove(product.id);
                  }
                }),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  'Sisa stok: ${product.stock}',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        product.stock <= 0 ? Colors.red : Colors.orange.shade800,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 90,
            child: TextField(
              controller: _qtyControllers[product.id],
              enabled: selected,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                isDense: true,
                suffixText: 'pack',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

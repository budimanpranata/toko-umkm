// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import '../../bloc/product_bloc.dart';
import '../model/product_model.dart';
import '../model/transaction_model.dart';
import '../database_helper.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final Map<int, Product> _cartProducts = {};
  final Map<int, int> _cartQuantities = {};
  final TextEditingController _penjualanSearchController =
      TextEditingController();
  String _username = 'Admin';
  String _storeName = 'Aplikasi Kasir UMKM Anggota Nurinsani';
  String? _storeLogo;
  String _storeAddress = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    // Memicu event BLoC untuk mengambil data saat halaman dimuat
    context.read<ProductBloc>().add(LoadProducts());
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('username') ?? 'Admin';
      _storeName =
          prefs.getString('storeName') ??
          'Aplikasi Kasir UMKM Anggota Nurinsani';
      _storeLogo = prefs.getString('storeLogo');
      _storeAddress = prefs.getString('storeAddress') ?? '';
    });
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${now.day} ${months[now.month - 1]} ${now.year}';
  }

  String _formatCurrency(double amount) {
    String result = amount.toStringAsFixed(0);
    result = result.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    return 'Rp $result';
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _incrementQuantity(Product product) {
    setState(() {
      int currentQty = _cartQuantities[product.id!] ?? 0;
      if (currentQty < product.stock) {
        _cartProducts[product.id!] = product;
        _cartQuantities[product.id!] = currentQty + 1;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stok produk tidak mencukupi')),
        );
      }
    });
  }

  void _decrementQuantity(Product product) {
    setState(() {
      if ((_cartQuantities[product.id!] ?? 0) > 0) {
        _cartQuantities[product.id!] = _cartQuantities[product.id!]! - 1;
        if (_cartQuantities[product.id!] == 0) {
          _cartProducts.remove(product.id!);
          _cartQuantities.remove(product.id!);
        }
      }
    });
  }

  void _clearCart() {
    setState(() {
      _cartProducts.clear();
      _cartQuantities.clear();
    });
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text(
              'Konfirmasi Keluar',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: const Text(
              'Apakah Anda yakin ingin keluar dari aplikasi?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Batal',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Keluar',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (mounted) context.go('/login');
    }
  }

  void _showPaymentDialog(double total) {
    final cashController = TextEditingController();
    double cashReceived = 0;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            double change = cashReceived - total;
            bool isValid = cashReceived >= total;

            return AlertDialog(
              title: const Text(
                'Proses Pembayaran',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Belanja: ${_formatCurrency(total)}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: cashController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Jumlah Uang Diterima',
                      prefixText: 'Rp ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (value) {
                      setStateDialog(() {
                        cashReceived = double.tryParse(value) ?? 0;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    change >= 0
                        ? 'Kembalian: ${_formatCurrency(change)}'
                        : 'Uang Kurang: ${_formatCurrency(change.abs())}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: change >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Batal',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed:
                      isValid
                          ? () async {
                            await DatabaseHelper.instance.processTransaction(
                              _cartProducts,
                              _cartQuantities,
                              total,
                            );
                            _clearCart();
                            if (context.mounted) {
                              Navigator.pop(context); // Tutup dialog
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Pembayaran berhasil!'),
                                ),
                              );
                              context.read<ProductBloc>().add(
                                const LoadProducts(),
                              );
                            }
                          }
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(
                    'Konfirmasi',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _exportToCSV(int? month, int year) async {
    try {
      final transactions = await DatabaseHelper.instance.readAllTransactions(
        month: month,
        year: year,
      );
      if (transactions.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tidak ada data untuk diexport')),
          );
        }
        return;
      }

      List<List<dynamic>> rows = [];
      rows.add([
        'ID Transaksi',
        'Tanggal',
        'Total Item',
        'Total Harga',
        'Detail Produk',
      ]);

      for (var trx in transactions) {
        String details =
            trx.items
                ?.map((i) => '${i.productName} (${i.quantity}x)')
                .join(', ') ??
            '';
        rows.add([trx.id, trx.date, trx.totalItems, trx.totalPrice, details]);
      }

      String csv = const ListToCsvConverter().convert(rows);
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/Laporan_Transaksi_${month ?? 'Semua'}_$year.csv';
      final file = File(path);
      await file.writeAsString(csv);

      await Share.shareXFiles([
        XFile(path),
      ], text: 'Laporan Transaksi Toko Snack');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal export: $e')));
      }
    }
  }

  void _showTransactionHistoryDialog() {
    int? selectedMonth = DateTime.now().month;
    int selectedYear = DateTime.now().year;

    final months = [
      'Semua Bulan',
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text(
                'Riwayat Transaksi',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<int?>(
                            value: selectedMonth,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            items: List.generate(13, (index) {
                              return DropdownMenuItem<int?>(
                                value: index == 0 ? null : index,
                                child: Text(months[index]),
                              );
                            }),
                            onChanged: (value) {
                              setStateDialog(() {
                                selectedMonth = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<int>(
                            value: selectedYear,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            items: List.generate(5, (index) {
                              int year = DateTime.now().year - index;
                              return DropdownMenuItem<int>(
                                value: year,
                                child: Text(year.toString()),
                              );
                            }),
                            onChanged: (value) {
                              if (value != null) {
                                setStateDialog(() {
                                  selectedYear = value;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: FutureBuilder<List<TransactionModel>>(
                        future: DatabaseHelper.instance.readAllTransactions(
                          month: selectedMonth,
                          year: selectedYear,
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Center(
                              child: CircularProgressIndicator(
                                color: Colors.green.shade700,
                              ),
                            );
                          } else if (snapshot.hasError) {
                            return Center(
                              child: Text('Error: ${snapshot.error}'),
                            );
                          } else if (!snapshot.hasData ||
                              snapshot.data!.isEmpty) {
                            return const Center(
                              child: Text(
                                'Belum ada riwayat transaksi.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            );
                          }

                          final transactions = snapshot.data!;
                          double grandTotal = transactions.fold(
                            0,
                            (sum, item) => sum + item.totalPrice,
                          );

                          // Mengelompokkan transaksi berdasarkan tanggal (per hari)
                          Map<String, List<TransactionModel>>
                          groupedTransactions = {};
                          for (var trx in transactions) {
                            final dateObj = DateTime.parse(trx.date);
                            final dateKey =
                                '${dateObj.day.toString().padLeft(2, '0')}/${dateObj.month.toString().padLeft(2, '0')}/${dateObj.year}';
                            if (!groupedTransactions.containsKey(dateKey)) {
                              groupedTransactions[dateKey] = [];
                            }
                            groupedTransactions[dateKey]!.add(trx);
                          }

                          final sortedDates = groupedTransactions.keys.toList();

                          return Column(
                            children: [
                              Expanded(
                                child: ListView.builder(
                                  itemCount: sortedDates.length,
                                  itemBuilder: (context, index) {
                                    final dateKey = sortedDates[index];
                                    final dailyTransactions =
                                        groupedTransactions[dateKey]!;

                                    double dailyTotal = dailyTransactions.fold(
                                      0,
                                      (sum, trx) => sum + trx.totalPrice,
                                    );
                                    int dailyItems = dailyTransactions.fold(
                                      0,
                                      (sum, trx) => sum + trx.totalItems,
                                    );

                                    return Card(
                                      margin: const EdgeInsets.symmetric(
                                        vertical: 4,
                                        horizontal: 4,
                                      ),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        side: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Theme(
                                        data: Theme.of(context).copyWith(
                                          dividerColor: Colors.transparent,
                                        ),
                                        child: ExpansionTile(
                                          leading: CircleAvatar(
                                            backgroundColor:
                                                Colors.green.shade50,
                                            child: Icon(
                                              Icons.calendar_month,
                                              color: Colors.green.shade700,
                                            ),
                                          ),
                                          title: Text(
                                            dateKey,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          subtitle: Text(
                                            'Total: ${_formatCurrency(dailyTotal)} | $dailyItems Item',
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                              fontSize: 13,
                                            ),
                                          ),
                                          children:
                                              dailyTransactions.map((trx) {
                                                final trxDate = DateTime.parse(
                                                  trx.date,
                                                );
                                                final timeStr =
                                                    '${trxDate.hour.toString().padLeft(2, '0')}:${trxDate.minute.toString().padLeft(2, '0')}';

                                                return Container(
                                                  margin: const EdgeInsets.only(
                                                    left: 16,
                                                    right: 16,
                                                    bottom: 8,
                                                    top: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade50,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    border: Border.all(
                                                      color:
                                                          Colors.grey.shade200,
                                                    ),
                                                  ),
                                                  child: ExpansionTile(
                                                    tilePadding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 16,
                                                        ),
                                                    title: Text(
                                                      'Transaksi $timeStr',
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    subtitle: Text(
                                                      _formatCurrency(
                                                        trx.totalPrice,
                                                      ),
                                                      style: TextStyle(
                                                        color:
                                                            Colors
                                                                .green
                                                                .shade900,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                    children:
                                                        trx.items?.map((item) {
                                                          return ListTile(
                                                            dense: true,
                                                            contentPadding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal:
                                                                      16,
                                                                ),
                                                            title: Text(
                                                              item.productName,
                                                              style:
                                                                  const TextStyle(
                                                                    fontSize:
                                                                        13,
                                                                  ),
                                                            ),
                                                            subtitle: Text(
                                                              '${item.quantity}x @ ${_formatCurrency(item.price)}',
                                                              style: TextStyle(
                                                                color:
                                                                    Colors
                                                                        .grey
                                                                        .shade600,
                                                                fontSize: 12,
                                                              ),
                                                            ),
                                                            trailing: Text(
                                                              _formatCurrency(
                                                                item.quantity *
                                                                    item.price,
                                                              ),
                                                              style: const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 13,
                                                              ),
                                                            ),
                                                          );
                                                        }).toList() ??
                                                        [],
                                                  ),
                                                );
                                              }).toList(),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.only(
                                  top: 16,
                                  bottom: 8,
                                  left: 8,
                                  right: 8,
                                ),
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Total Penjualan:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      _formatCurrency(grandTotal),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.green.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => _exportToCSV(selectedMonth, selectedYear),
                  child: const Text(
                    'Export CSV',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Tutup',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditProductDialog(Product product) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: product.name);
    final initialController = TextEditingController(text: product.initial);
    final priceController = TextEditingController(
      text: product.price.toStringAsFixed(0),
    );
    final stockController = TextEditingController(
      text: product.stock.toString(),
    );
    String currentImageUrl = product.imageUrl;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Edit Produk'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nama Produk',
                        ),
                        validator:
                            (value) =>
                                value == null || value.isEmpty
                                    ? 'Wajib diisi'
                                    : null,
                      ),
                      TextFormField(
                        controller: initialController,
                        decoration: const InputDecoration(labelText: 'Inisial'),
                        validator:
                            (value) =>
                                value == null || value.isEmpty
                                    ? 'Wajib diisi'
                                    : null,
                      ),
                      TextFormField(
                        controller: priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Harga Jual',
                        ),
                        validator:
                            (value) =>
                                value == null || value.isEmpty
                                    ? 'Wajib diisi'
                                    : null,
                      ),
                      TextFormField(
                        controller: stockController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Stok'),
                        validator:
                            (value) =>
                                value == null || value.isEmpty
                                    ? 'Wajib diisi'
                                    : null,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Gambar Produk',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                          final picker = ImagePicker();
                          // Melakukan pick file dan me-resize otomatis
                          final pickedFile = await picker.pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 600, // Ukuran lebar maks otomatis 600px
                            maxHeight: 600, // Ukuran tinggi maks otomatis 600px
                            imageQuality: 80, // Kompres kualitas gambar 80%
                          );
                          if (pickedFile != null) {
                            final dir =
                                await getApplicationDocumentsDirectory();
                            final fileName = path.basename(pickedFile.path);
                            // Simpan gambar ke dalam memory app agar tak hilang
                            final savedImage = await File(
                              pickedFile.path,
                            ).copy('${dir.path}/$fileName');
                            setStateDialog(() {
                              currentImageUrl = savedImage.path;
                            });
                          }
                        },
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade400),
                          ),
                          child:
                              currentImageUrl.isEmpty
                                  ? const Icon(
                                    Icons.add_a_photo,
                                    color: Colors.grey,
                                  )
                                  : ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child:
                                        currentImageUrl.startsWith('http')
                                            ? Image.network(
                                              currentImageUrl,
                                              fit: BoxFit.cover,
                                            )
                                            : Image.file(
                                              File(currentImageUrl),
                                              fit: BoxFit.cover,
                                            ),
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Batal',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      final updatedProduct = Product(
                        id: product.id,
                        name: nameController.text,
                        initial: initialController.text,
                        price: double.parse(priceController.text),
                        stock: int.parse(stockController.text),
                        imageUrl: currentImageUrl,
                        purchaseCount: product.purchaseCount,
                      );

                      context.read<ProductBloc>().add(
                        UpdateProduct(updatedProduct),
                      );
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Produk berhasil diubah!'),
                        ),
                      );
                    }
                  },
                  child: const Text(
                    'Simpan',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(Product product) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Hapus Produk',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Apakah Anda yakin ingin menghapus produk "${product.name}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                // Pastikan nama event BLoC sesuai dengan yang ada di product_bloc.dart
                context.read<ProductBloc>().add(DeleteProduct(product.id!));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Produk berhasil dihapus')),
                );
              },
              child: const Text(
                'Hapus',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeContent();
      case 1:
        return _buildPenjualanContent();
      case 2:
        return _SettingsTabScreen(onSettingsSaved: _loadSettings);
      default:
        return _buildHomeContent();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        title: const Text(
          'Beranda',
          style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
        ),
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Colors.white),
            tooltip: 'Riwayat Transaksi',
            onPressed: _showTransactionHistoryDialog,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            tooltip: 'Keluar',
            onPressed: _logout,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Color(0xFFC8E6C9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _buildBody(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: const Color(0xFF2E7D32),
        unselectedItemColor: Colors.grey.shade400,
        backgroundColor: Colors.white,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.point_of_sale_rounded),
            label: 'Penjualan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildUserInfoCard(),
          const SizedBox(height: 20),
          _buildCarouselCard(),
          const SizedBox(height: 20),
          _buildProductListCard(),
        ],
      ),
    );
  }

  // CARD 1: Informasi Toko dan User
  Widget _buildUserInfoCard() {
    return Card(
      elevation: 4,
      shadowColor: Colors.green.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            _storeLogo == null || _storeLogo!.isEmpty
                ? CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.green.shade100,
                  child: Icon(
                    Icons.storefront,
                    size: 28,
                    color: Colors.green.shade900,
                  ),
                )
                : CircleAvatar(
                  radius: 28,
                  backgroundImage: FileImage(File(_storeLogo!)),
                ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _storeName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  if (_storeAddress.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      _storeAddress,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    'Admin: $_username',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: _logout,
                    child: const Text(
                      'Keluar (Logout)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: Colors.green.shade700,
                ),
                const SizedBox(height: 4),
                Text(
                  _getFormattedDate(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // CARD 2: Carousel Produk Fast Moving
  Widget _buildCarouselCard() {
    return Card(
      elevation: 4,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Produk Fast Moving (3 Bulan)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 130,
              child: BlocBuilder<ProductBloc, ProductState>(
                builder: (context, state) {
                  if (state is ProductLoading) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: Colors.green.shade700,
                      ),
                    );
                  } else if (state is ProductError) {
                    return Center(child: Text('Error: ${state.errorMessage}'));
                  } else if (state is ProductLoaded) {
                    if (state.fastMovingProducts.isEmpty) {
                      return const Center(
                        child: Text(
                          'Belum ada data penjualan 3 bulan terakhir.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }
                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: state.fastMovingProducts.length,
                      itemBuilder: (context, index) {
                        final product = state.fastMovingProducts[index];
                        return Container(
                          width: 240,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              colors: [
                                Colors.green.shade300,
                                Colors.green.shade700,
                              ],
                            ),
                          ),
                          child: Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child:
                                      product.imageUrl.startsWith('http')
                                          ? Image.network(
                                            product.imageUrl,
                                            width: 80,
                                            height: 80,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    Container(
                                                      width: 80,
                                                      height: 80,
                                                      color: Colors.white24,
                                                      child: const Icon(
                                                        Icons.fastfood,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                          )
                                          : Image.file(
                                            File(product.imageUrl),
                                            width: 80,
                                            height: 80,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    Container(
                                                      width: 80,
                                                      height: 80,
                                                      color: Colors.white24,
                                                      child: const Icon(
                                                        Icons.fastfood,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                          ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    top: 16.0,
                                    bottom: 16.0,
                                    right: 12.0,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        product.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _formatCurrency(product.price),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // CARD 3: List Produk dari SQLite menggunakan BLoC
  Widget _buildProductListCard() {
    return Card(
      elevation: 4,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daftar Produk',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (value) {
                if (value.isEmpty) {
                  context.read<ProductBloc>().add(const LoadProducts());
                } else {
                  context.read<ProductBloc>().add(SearchProducts(value));
                }
              },
              decoration: InputDecoration(
                hintText: 'Cari produk (nama / inisial)...',
                hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                prefixIcon: Icon(Icons.search, color: Colors.green.shade700),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.green.shade700),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildProductListBuilder(isScrollable: false),
          ],
        ),
      ),
    );
  }

  // HALAMAN 2: Penjualan / Kasir
  Widget _buildPenjualanContent() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Menu Penjualan',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _penjualanSearchController,
                  onChanged: (value) {
                    if (value.isEmpty) {
                      context.read<ProductBloc>().add(const LoadProducts());
                    } else {
                      context.read<ProductBloc>().add(SearchProducts(value));
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Cari produk (nama / inisial)...',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade400,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Colors.green.shade700,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.green.shade700),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _buildProductListBuilder(
              isScrollable: true,
              isPenjualan: true,
            ),
          ),
          _buildCartSummaryCard(),
        ],
      ),
    );
  }

  Widget _buildCartSummaryCard() {
    if (_cartQuantities.isEmpty) return const SizedBox();

    double total = 0;
    int totalItems = 0;
    _cartQuantities.forEach((id, qty) {
      total += _cartProducts[id]!.price * qty;
      totalItems += qty;
    });

    return Card(
      elevation: 6,
      margin: const EdgeInsets.only(top: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ringkasan Pesanan',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 120),
              child: SingleChildScrollView(
                child: Column(
                  children:
                      _cartQuantities.entries.map((entry) {
                        final product = _cartProducts[entry.key]!;
                        final qty = entry.value;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${product.name} (x$qty)',
                                  style: const TextStyle(fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                _formatCurrency(product.price * qty),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Divider(),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total ($totalItems Item)',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  _formatCurrency(total),
                  style: TextStyle(
                    color: Colors.green.shade900,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _clearCart,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Batal',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () => _showPaymentDialog(total),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Proses Pembayaran',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // WIDGET REUSABLE: List Produk untuk Home & Penjualan
  Widget _buildProductListBuilder({
    bool isScrollable = false,
    bool isPenjualan = false,
  }) {
    return BlocBuilder<ProductBloc, ProductState>(
      builder: (context, state) {
        if (state is ProductLoading) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: Colors.green.shade700),
            ),
          );
        } else if (state is ProductError) {
          return Center(child: Text('Gagal memuat: ${state.errorMessage}'));
        } else if (state is ProductLoaded) {
          if (state.products.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Produk tidak ditemukan',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            );
          }
          return ListView.separated(
            shrinkWrap: !isScrollable,
            physics:
                isScrollable
                    ? const AlwaysScrollableScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
            itemCount: state.products.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final product = state.products[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child:
                      product.imageUrl.startsWith('http')
                          ? Image.network(
                            product.imageUrl,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (context, error, stackTrace) => Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey.shade200,
                                  child: Icon(
                                    Icons.fastfood,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                          )
                          : Image.file(
                            File(product.imageUrl),
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (context, error, stackTrace) => Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey.shade200,
                                  child: Icon(
                                    Icons.fastfood,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                          ),
                ),
                title: Text(
                  product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                subtitle:
                    isPenjualan
                        ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              _formatCurrency(product.price),
                              style: TextStyle(
                                color: Colors.green.shade900,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Terbeli: ${product.purchaseCount}x  |  Stok: ${product.stock}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        )
                        : Text(
                          'Terbeli: ${product.purchaseCount}x  |  Stok: ${product.stock}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                trailing:
                    isPenjualan
                        ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              color: Colors.green.shade700,
                              onPressed: () => _decrementQuantity(product),
                            ),
                            Text(
                              '${_cartQuantities[product.id!] ?? 0}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              color: Colors.green.shade700,
                              onPressed: () => _incrementQuantity(product),
                            ),
                          ],
                        )
                        : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatCurrency(product.price),
                              style: TextStyle(
                                color: Colors.green.shade900,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _showEditProductDialog(product);
                                } else if (value == 'delete') {
                                  _showDeleteConfirmationDialog(product);
                                }
                              },
                              itemBuilder:
                                  (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Edit'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Hapus'),
                                    ),
                                  ],
                            ),
                          ],
                        ),
              );
            },
          );
        }
        return const SizedBox();
      },
    );
  }
}

class _SettingsTabScreen extends StatelessWidget {
  final VoidCallback onSettingsSaved;

  const _SettingsTabScreen({required this.onSettingsSaved});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: const TabBar(
              labelColor: Color(0xFF2E7D32),
              unselectedLabelColor: Colors.grey,
              indicatorColor: Color(0xFF2E7D32),
              labelPadding: EdgeInsets.symmetric(horizontal: 8),
              tabs: [
                Tab(text: 'Tambah Produk'),
                Tab(text: 'Pencatatan'),
                Tab(text: 'Settings'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                const _TambahProdukForm(), // Tab 1: Form tambah produk yang sudah ada
                const _PencatatanScreen(), // Tab 2: Pencatatan Keuangan
                _StoreSettingsForm(
                  onSave: onSettingsSaved,
                ), // Tab 3: Pengaturan Toko
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreSettingsForm extends StatefulWidget {
  final VoidCallback onSave;
  const _StoreSettingsForm({required this.onSave});

  @override
  State<_StoreSettingsForm> createState() => _StoreSettingsFormState();
}

class _StoreSettingsFormState extends State<_StoreSettingsForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  String? _selectedImagePath;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _nameController.text =
            prefs.getString('storeName') ?? 'Toko Snack Anisa';
        _addressController.text = prefs.getString('storeAddress') ?? '';
        _selectedImagePath = prefs.getString('storeLogo');
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('storeName', _nameController.text);
      await prefs.setString('storeAddress', _addressController.text);
      if (_selectedImagePath != null) {
        await prefs.setString('storeLogo', _selectedImagePath!);
      }
      widget.onSave();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengaturan toko berhasil disimpan!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: Colors.green.shade700),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 4,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pengaturan Toko',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Nama Toko',
                    prefixIcon: const Icon(Icons.store),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator:
                      (value) =>
                          value == null || value.isEmpty ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    labelText: 'Alamat Toko (Opsional)',
                    prefixIcon: const Icon(Icons.location_on),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Logo Toko',
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final pickedFile = await picker.pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 400,
                      maxHeight: 400,
                      imageQuality: 80,
                    );
                    if (pickedFile != null) {
                      final dir = await getApplicationDocumentsDirectory();
                      final fileName = path.basename(pickedFile.path);
                      final savedImage = await File(
                        pickedFile.path,
                      ).copy('${dir.path}/$fileName');
                      setState(() {
                        _selectedImagePath = savedImage.path;
                      });
                    }
                  },
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child:
                        _selectedImagePath == null ||
                                _selectedImagePath!.isEmpty
                            ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate_outlined,
                                  size: 32,
                                  color: Colors.green.shade700,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Pilih Logo',
                                  style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            )
                            : ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.file(
                                File(_selectedImagePath!),
                                fit: BoxFit.cover,
                              ),
                            ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Simpan Pengaturan',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PencatatanScreen extends StatefulWidget {
  const _PencatatanScreen();

  @override
  State<_PencatatanScreen> createState() => _PencatatanScreenState();
}

class _PencatatanScreenState extends State<_PencatatanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedType = 'Pengeluaran';

  List<FinancialRecordModel> _records = [];
  List<TransactionModel> _transactions = [];
  bool _isLoading = true;
  String _selectedFilter = 'Semua';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final records = await DatabaseHelper.instance.readAllFinancialRecords();
    final transactions = await DatabaseHelper.instance.readAllTransactions();
    if (mounted) {
      setState(() {
        _records = records;
        _transactions = transactions;
        _isLoading = false;
      });
    }
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      final record = FinancialRecordModel(
        type: _selectedType,
        amount: double.parse(_amountController.text),
        description: _descController.text,
        date: DateTime.now().toIso8601String(),
      );
      await DatabaseHelper.instance.insertFinancialRecord(record);
      _amountController.clear();
      _descController.clear();
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pencatatan berhasil disimpan')),
        );
      }
    }
  }

  void _deleteRecord(int id) async {
    await DatabaseHelper.instance.deleteFinancialRecord(id);
    _loadData();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Catatan dihapus')));
    }
  }

  String _formatCurrency(double amount) {
    String result = amount.toStringAsFixed(0);
    result = result.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    return 'Rp $result';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: Colors.green.shade700),
      );
    }

    DateTime now = DateTime.now();
    DateTime todayStart = DateTime(now.year, now.month, now.day);
    DateTime? startDate;

    if (_selectedFilter == 'Hari Ini') {
      startDate = todayStart;
    } else if (_selectedFilter == '7 Hari Terakhir') {
      startDate = todayStart.subtract(const Duration(days: 7));
    } else if (_selectedFilter == 'Sebulan Terakhir') {
      startDate = todayStart.subtract(const Duration(days: 30));
    }

    List<FinancialRecordModel> filteredRecords = _records;
    List<TransactionModel> filteredTransactions = _transactions;

    if (startDate != null) {
      final start = startDate;
      filteredRecords =
          _records.where((r) {
            DateTime rDate = DateTime.parse(r.date);
            return rDate.isAfter(start) || rDate.isAtSameMomentAs(start);
          }).toList();

      filteredTransactions =
          _transactions.where((t) {
            DateTime tDate = DateTime.parse(t.date);
            return tDate.isAfter(start) || tDate.isAtSameMomentAs(start);
          }).toList();
    }

    double totalSales = filteredTransactions.fold(
      0,
      (sum, item) => sum + item.totalPrice,
    );
    double totalPendapatanLain = filteredRecords
        .where((r) => r.type == 'Pendapatan')
        .fold(0, (s, r) => s + r.amount);
    double totalPengeluaran = filteredRecords
        .where((r) => r.type == 'Pengeluaran')
        .fold(0, (s, r) => s + r.amount);
    double totalHutang = _records
        .where((r) => r.type == 'Hutang')
        .fold(0, (s, r) => s + r.amount);
    double totalAngsuranHutang = _records
        .where((r) => r.type == 'Angsuran Hutang')
        .fold(0, (s, r) => s + r.amount);
    double labaBersih = (totalSales + totalPendapatanLain) - totalPengeluaran;
    double sisaHutang = totalHutang - totalAngsuranHutang;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Laporan Card
          Card(
            elevation: 4,
            shadowColor: Colors.black12,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Laporan Laba Rugi',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 0,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedFilter,
                            icon: Icon(
                              Icons.arrow_drop_down,
                              color: Colors.green.shade700,
                              size: 20,
                            ),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                            items:
                                [
                                  'Semua',
                                  'Hari Ini',
                                  '7 Hari Terakhir',
                                  'Sebulan Terakhir',
                                ].map((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  );
                                }).toList(),
                            onChanged: (newValue) {
                              if (newValue != null) {
                                setState(() => _selectedFilter = newValue);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildReportRow(
                    'Penjualan (Aplikasi)',
                    totalSales,
                    Colors.green,
                  ),
                  _buildReportRow(
                    'Pendapatan Lain',
                    totalPendapatanLain,
                    Colors.green,
                  ),
                  _buildReportRow('Pengeluaran', totalPengeluaran, Colors.red),
                  const Divider(height: 24, thickness: 1),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Laba Bersih',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _formatCurrency(labaBersih),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: labaBersih >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildReportRow(
                    'Sisa Hutang',
                    sisaHutang,
                    Colors.green.shade700,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Input Form Card
          Card(
            elevation: 4,
            shadowColor: Colors.black12,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tambah Pencatatan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedType,
                      decoration: InputDecoration(
                        labelText: 'Jenis Transaksi',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items:
                          [
                            'Pengeluaran',
                            'Pendapatan',
                            'Hutang',
                            'Angsuran Hutang',
                          ].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                      onChanged: (newValue) {
                        setState(() {
                          _selectedType = newValue!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Nominal',
                        prefixText: 'Rp ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator:
                          (value) =>
                              value == null || value.isEmpty
                                  ? 'Wajib diisi'
                                  : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descController,
                      decoration: InputDecoration(
                        labelText: 'Keterangan (Cth: Bayar Listrik)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator:
                          (value) =>
                              value == null || value.isEmpty
                                  ? 'Wajib diisi'
                                  : null,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Simpan Catatan',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // History List
          const Text(
            'Riwayat Pencatatan',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredRecords.length,
            itemBuilder: (context, index) {
              final record = filteredRecords[index];
              final date = DateTime.parse(record.date);
              final isPengeluaran = record.type == 'Pengeluaran';
              final isHutang = record.type == 'Hutang';
              final isAngsuran = record.type == 'Angsuran Hutang';

              Color bgColor = Colors.green.shade50;
              Color iconColor = Colors.green;
              IconData iconData = Icons.arrow_downward;

              if (isPengeluaran) {
                bgColor = Colors.red.shade50;
                iconColor = Colors.red;
                iconData = Icons.arrow_outward;
              } else if (isHutang) {
                bgColor = Colors.green.shade50;
                iconColor = Colors.green.shade700;
                iconData = Icons.account_balance_wallet;
              } else if (isAngsuran) {
                bgColor = Colors.blue.shade50;
                iconColor = Colors.blue;
                iconData = Icons.credit_score;
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: bgColor,
                    child: Icon(iconData, color: iconColor),
                  ),
                  title: Text(
                    record.description,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${record.type} • ${date.day}/${date.month}/${date.year}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatCurrency(record.amount),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: iconColor,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete,
                          color: Colors.grey,
                          size: 20,
                        ),
                        onPressed: () => _deleteRecord(record.id!),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReportRow(String label, double amount, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            _formatCurrency(amount),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _TambahProdukForm extends StatefulWidget {
  const _TambahProdukForm();

  @override
  State<_TambahProdukForm> createState() => _TambahProdukFormState();
}

class _TambahProdukFormState extends State<_TambahProdukForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _initialController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  String? _selectedImagePath;

  @override
  void dispose() {
    _nameController.dispose();
    _initialController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final newProduct = Product(
        name: _nameController.text,
        initial: _initialController.text,
        imageUrl:
            _selectedImagePath ?? 'https://picsum.photos/200', // Gambar default
        purchaseCount: 0,
        price: double.parse(_priceController.text),
        stock: int.parse(_stockController.text),
      );

      context.read<ProductBloc>().add(AddProduct(newProduct));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produk berhasil ditambahkan!')),
      );

      _formKey.currentState!.reset();
      _nameController.clear();
      _initialController.clear();
      _priceController.clear();
      _stockController.clear();
      setState(() {
        _selectedImagePath = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 4,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tambah Produk Baru',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Nama Produk',
                    prefixIcon: const Icon(Icons.fastfood_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator:
                      (value) =>
                          value == null || value.isEmpty ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _initialController,
                  decoration: InputDecoration(
                    labelText: 'Inisial (Contoh: KKB)',
                    prefixIcon: const Icon(Icons.spellcheck),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator:
                      (value) =>
                          value == null || value.isEmpty ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Harga Jual',
                          prefixText: 'Rp ',
                          prefixIcon: const Icon(Icons.payments_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Wajib diisi';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Tidak valid';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _stockController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Stok Awal',
                          prefixIcon: const Icon(Icons.inventory_2_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Wajib diisi';
                          }
                          if (int.tryParse(value) == null) return 'Tidak valid';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Gambar Produk (Opsional)',
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final pickedFile = await picker.pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 600, // Ukuran lebar maks otomatis 600px
                      maxHeight: 600, // Ukuran tinggi maks otomatis 600px
                      imageQuality: 80, // Kualitas dikompres 80%
                    );
                    if (pickedFile != null) {
                      final dir = await getApplicationDocumentsDirectory();
                      final fileName = path.basename(pickedFile.path);
                      final savedImage = await File(
                        pickedFile.path,
                      ).copy('${dir.path}/$fileName');
                      setState(() {
                        _selectedImagePath = savedImage.path;
                      });
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child:
                        _selectedImagePath == null
                            ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate_outlined,
                                  size: 40,
                                  color: Colors.green.shade700,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Pilih Gambar',
                                  style: TextStyle(
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            )
                            : ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child:
                                  _selectedImagePath!.startsWith('http')
                                      ? Image.network(
                                        _selectedImagePath!,
                                        fit: BoxFit.cover,
                                      )
                                      : Image.file(
                                        File(_selectedImagePath!),
                                        fit: BoxFit.cover,
                                      ),
                            ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Simpan Produk',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';

/// Backup & restore seluruh data aplikasi ke satu file JSON:
/// isi semua tabel database, pengaturan toko, dan file gambar (base64).
class BackupService {
  static const _appId = 'tokosnack';
  static const _formatVersion = 1;

  static const _tables = [
    'products',
    'transactions',
    'transaction_items',
    'users',
    'financial_records',
    'cash_counts',
  ];

  static const _prefKeys = ['storeName', 'storeAddress', 'storeLogo'];

  /// Membuat file backup di folder sementara dan mengembalikan file-nya.
  static Future<File> createBackup() async {
    final db = await DatabaseHelper.instance.database;
    final prefs = await SharedPreferences.getInstance();

    final tables = <String, List<Map<String, Object?>>>{};
    for (final table in _tables) {
      tables[table] = await db.query(table);
    }

    final settings = <String, String>{};
    for (final key in _prefKeys) {
      final value = prefs.getString(key);
      if (value != null) settings[key] = value;
    }

    // Kumpulkan file gambar lokal (gambar produk & logo toko)
    final files = <String, String>{};
    final localPaths = <String>[
      ...tables['products']!.map((row) => row['imageUrl'] as String? ?? ''),
      settings['storeLogo'] ?? '',
    ];
    for (final filePath in localPaths) {
      if (filePath.isEmpty || filePath.startsWith('http')) continue;
      final file = File(filePath);
      if (await file.exists()) {
        files[p.basename(filePath)] = base64Encode(await file.readAsBytes());
      }
    }

    final backup = {
      'app': _appId,
      'formatVersion': _formatVersion,
      'dbVersion': await db.getVersion(),
      'createdAt': DateTime.now().toIso8601String(),
      'tables': tables,
      'settings': settings,
      'files': files,
    };

    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp =
        '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}';
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/backup_tokosnack_$stamp.json');
    await file.writeAsString(jsonEncode(backup));
    return file;
  }

  /// Membaca ringkasan isi file backup (untuk konfirmasi sebelum restore).
  /// Melempar [FormatException] jika file bukan backup yang valid.
  static Future<Map<String, dynamic>> readBackup(File file) async {
    final dynamic data;
    try {
      data = jsonDecode(await file.readAsString());
    } catch (_) {
      throw const FormatException('File bukan file backup yang valid.');
    }
    if (data is! Map<String, dynamic> || data['app'] != _appId) {
      throw const FormatException('File bukan backup aplikasi ini.');
    }
    final db = await DatabaseHelper.instance.database;
    if ((data['dbVersion'] as int? ?? 0) > await db.getVersion()) {
      throw const FormatException(
        'Backup dibuat dari versi aplikasi yang lebih baru. Update aplikasi dulu.',
      );
    }
    return data;
  }

  /// Mengganti SELURUH data saat ini dengan isi backup.
  static Future<void> restoreBackup(Map<String, dynamic> data) async {
    // 1. Tulis ulang file gambar ke folder dokumen aplikasi
    final docsDir = await getApplicationDocumentsDirectory();
    final restoredPaths = <String, String>{};
    final files = Map<String, dynamic>.from(data['files'] as Map? ?? {});
    for (final entry in files.entries) {
      final target = File('${docsDir.path}/${entry.key}');
      await target.writeAsBytes(base64Decode(entry.value as String));
      restoredPaths[entry.key] = target.path;
    }

    String fixPath(String original) {
      if (original.isEmpty || original.startsWith('http')) return original;
      return restoredPaths[p.basename(original)] ?? original;
    }

    // 2. Ganti isi semua tabel dalam satu transaksi
    final db = await DatabaseHelper.instance.database;
    final tables = Map<String, dynamic>.from(data['tables'] as Map);
    await db.transaction((txn) async {
      for (final table in _tables) {
        if (!tables.containsKey(table)) continue;
        await txn.delete(table);
        for (final row in tables[table] as List) {
          final values = Map<String, Object?>.from(row as Map);
          if (table == 'products') {
            values['imageUrl'] = fixPath(values['imageUrl'] as String? ?? '');
          }
          await txn.insert(table, values);
        }
      }
    });

    // 3. Pulihkan pengaturan toko
    final prefs = await SharedPreferences.getInstance();
    final settings = Map<String, dynamic>.from(data['settings'] as Map? ?? {});
    for (final key in _prefKeys) {
      final value = settings[key] as String?;
      if (value == null) continue;
      await prefs.setString(key, key == 'storeLogo' ? fixPath(value) : value);
    }
  }
}

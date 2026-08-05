import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  String? _storeLogo;
  String _storeName = 'Aplikasi Kasir UMKM Anggota Nurinsani';

  @override
  void initState() {
    super.initState();
    _loadSettingsAndCheckLogin();
  }

  Future<void> _loadSettingsAndCheckLogin() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _storeLogo = prefs.getString('storeLogo');
        _storeName =
            prefs.getString('storeName') ?? 'Aplikasi UMKM Anggota NURISANI';
      });
    }

    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    if (isLoggedIn) {
      if (mounted) context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Color(0xFFC8E6C9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _storeLogo == null || _storeLogo!.isEmpty
                      ? Image.asset(
                        'assets/logo.png',
                        width: 240,
                        height: 240,
                        fit: BoxFit.contain,
                      )
                      : ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.file(
                          File(_storeLogo!),
                          width: 240,
                          height: 240,
                          fit: BoxFit.cover,
                        ),
                      ),
                  const SizedBox(height: 24),
                  Text(
                    'Selamat Datang di\n$_storeName',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Kelola toko snack Anda dengan mudah',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => context.go('/login'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'MASUK',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

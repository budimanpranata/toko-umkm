import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'ui/login_page.dart';
import 'ui/home_page.dart';
import 'ui/landing_page.dart';
import 'bloc/product_bloc.dart';

void main() {
  runApp(const MyApp());
}

final GoRouter _router = GoRouter(
  initialLocation: '/landing',
  routes: [
    GoRoute(path: '/landing', builder: (context, state) => const LandingPage()),
    GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
    GoRoute(path: '/home', builder: (context, state) => const HomePage()),
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [BlocProvider(create: (context) => ProductBloc())],
      child: MaterialApp.router(
        title: 'Toko Snack Anisa',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFFA751)),
          useMaterial3: true,
        ),
        routerConfig: _router,
      ),
    );
  }
}

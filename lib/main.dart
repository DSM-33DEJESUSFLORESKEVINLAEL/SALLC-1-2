// Crédito de autor cifrado: <PEGA AQUÍ LA CADENA>
// Todos los derechos reservados.
// Este código es parte de la aplicación [Mi app].
// Prohibida su reproducción o distribución sin autorización.

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // ✅ IMPORTANTE
import 'package:miapp/db/opciontablas.dart';
import 'package:miapp/navigation/app_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      if (kDebugMode) {
        // await DBHelper().resetDatabase(); // Solo si lo necesitas
      }

      await DatabaseHelper.instance.initDB();
    } catch (e, s) {
      debugPrint('❌ Error al inicializar la app: $e\n$s');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        } else if (snapshot.hasError) {
          return MaterialApp(
            home: Scaffold(
              body: Center(child: Text('❌ Error al iniciar la base de datos')),
            ),
          );
        } else {
          return MaterialApp.router(
            title: 'App con GoRouter',
            routerConfig: AppRouter.router,
            debugShowCheckedModeBanner: false,
            locale: const Locale('es', ''), // ✅ Español por defecto
            supportedLocales: const [
              Locale('es', ''),
              Locale('en', ''),
            ],
            localizationsDelegates: [ // ✅ SIN `const`
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: ThemeData(
              primarySwatch: Colors.blue,
              visualDensity: VisualDensity.adaptivePlatformDensity,
            ),
          );
        }
      },
    );
  }

  @override
  void dispose() {
    DatabaseHelper.instance.closeDB();
    super.dispose();
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../db/opciontablas.dart';
import 'package:logger/logger.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:package_info_plus/package_info_plus.dart';

final Logger logger = Logger();

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _version = '';

  @override
  void initState() {
    super.initState();
    // _usernameController.text = 'ASESORIA';
    // _passwordController.text  = 'ASE19*';
    _verificarPrimerInicio(); // 👈 Añade esta línea
    _cargarVersion();
  }

  void _cargarVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _version = 'v${info.version}';
    });
  }

  void _login() async {
    String username = _usernameController.text.trim();
    String password = _passwordController.text.trim();

    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingrese su usuario')),
      );
      return;
    }

    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingrese su contraseña')),
      );
      return;
    }
    if (username.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario demasiado corto')),
      );
      return;
    }

    if (password.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña demasiado corta')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    bool datosSincronizados = prefs.getBool('datosSincronizados') ?? false;

    final loginResponse = await _authService.login(username, password);

    if (loginResponse != null &&
        loginResponse["DATA"] != null &&
        loginResponse["DATA"].isNotEmpty) {
      await prefs.setBool('loggedIn', true);

      List<dynamic> empresasDisponibles = loginResponse["DATA"];

      if (datosSincronizados) {
        logger.i("✅ Datos ya sincronizados. Saltando sincronización.");
        if (mounted) context.go('/home');
        _usernameController.text = ''; // <-- Limpia el campo usuario
        _passwordController.text = ''; // <-- Limpia el campo contraseña
      } else {
        if (empresasDisponibles.length == 1) {
          _procesarEmpresaSeleccionada(
              empresasDisponibles[0], username, password);
        } else {
          _mostrarDialogoSeleccion(empresasDisponibles, username, password);
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Usuario o contraseña incorrectos o sin conexión')),
        );
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

// //-------------------VERIFICACION POR PRIMERA VEZ-------------------------------------
  void _verificarPrimerInicio() async {
    final prefs = await SharedPreferences.getInstance();
    bool isFirstLaunch = prefs.getBool('isFirstLaunch') ?? true;
    bool loggedIn = prefs.getBool('loggedIn') ?? false;
    bool datosSincronizados = prefs.getBool('datosSincronizados') ?? false;

    logger.i(
        "🧪 Flags actuales → isFirstLaunch: $isFirstLaunch | loggedIn: $loggedIn | datosSincronizados: $datosSincronizados");

    if (isFirstLaunch) {
      logger.i("🚀 Primer inicio detectado.");
      await prefs.setBool('isFirstLaunch', false);
    } else {
      logger.i("🔐 Mostrando login. Esperando ingreso de usuario/contraseña.");
    }
  }

//-----------------------------MOSTRAR MAS EMPRESA---------------------------------------

  void _mostrarDialogoSeleccion(
      List<dynamic> empresas, String username, String password) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Selecciona una base"),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height *
                    0.5, // ⬅️ limita altura
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: empresas.map((empresaData) {
                  String empresa = empresaData["EMPRESA"].toString();
                  String base = empresaData["BASE"].toString();
                  return ListTile(
                    title: Text("Base: $base"),
                    onTap: () {
                      logger
                          .i("🔍 Empresa seleccionada: $empresa - Base: $base");
                      Navigator.pop(context);
                      _procesarEmpresaSeleccionada(
                          empresaData, username, password);
                    },
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

//-----------------------------MOSTRAR DATOS SIN SQL---------------------------------------

  Future<String> obtenerSerieDesdeSQLite(String empresa, String base) async {
    final db = await DatabaseHelper.instance.database;
    List<Map<String, dynamic>> result = await db.rawQuery('''
    SELECT serie FROM bases WHERE empresa = ? AND base = ?
  ''', [empresa, base]);

    if (result.isNotEmpty) {
      String serie = result.first["serie"]?.toString() ?? "SIN_SERIE";
      logger.i("✅ Serie encontrada en SQLite: $serie");
      return serie;
    } else {
      logger.e(
          "⛔ ⛔ No se encontró 'SERIE' en SQLite para EMPRESA: $empresa, BASE: $base. Verifica la base de datos.");
      return "SIN_SERIE";
    }
  }

  void _procesarEmpresaSeleccionada(Map<String, dynamic>? empresaData,
      String username, String password) async {
    if (!mounted) return;

    // Mostrar el diálogo de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        title: Text("CARGANDO DATOS..."),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
                "Cargando datos esenciales para comenzar su sesión. Un momento, por favor."),
          ],
        ),
      ),
    );

    try {
      if (empresaData == null) throw Exception("empresaData es null");

      String empresaId =
          (empresaData["EMPRESA"] ?? empresaData["empresa"])?.toString() ?? "";
      String baseId =
          (empresaData["BASE"] ?? empresaData["base"])?.toString() ?? "";

      if (empresaId.isEmpty || baseId.isEmpty)
        throw Exception("Empresa o Base vacía");

      if (await _authService.hasInternetConnection()) {
        final empresaResponse = await _authService.syncUsuarioEmpresaBase(
            username, password, empresaId, baseId);
        if (empresaResponse != null) {
          String serie =
              await _authService.obtenerSerieDesdeSQLite(empresaId, baseId);
          await _printSQLiteData(empresaId, baseId, serie);
        } else {
          throw Exception("No se pudo sincronizar empresa desde API");
        }
      } else {
        String serie =
            await _authService.obtenerSerieDesdeSQLite(empresaId, baseId);
        await _printSQLiteData(empresaId, baseId, serie);
      }

      // ✅ Guardamos que ya se sincronizaron los datos correctamente
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('datosSincronizados', true);

      if (mounted) {
        Navigator.pop(context); // ❌ Cierra el diálogo
        // context.go('/home');    // ✅ Redirige a la pantalla principal
        context.push('/home'); // si quieres poder regresar al login
        _usernameController.text = ''; // <-- Limpia el campo usuario
        _passwordController.text = ''; // <-- Limpia el campo contraseña
      }
    } catch (e) {
      Navigator.pop(context); // ❌ Cierra el diálogo en caso de error
      logger.e("❌ Error durante la sincronización: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al cargar la aplicación: $e")),
        );
      }
    }
  }

  /// 🔹 **Consulta los datos guardados en SQLite y sincroniza desde la API**
  Future<void> _printSQLiteData(
      String empresaId, String baseId, String serie) async {
    final db = await DatabaseHelper.instance.database;

    final tables = [
      'accesos_permisos',
      'accesos_usuarios',
      'bases',
      'desDet',
      'desMstr',
      'empresas',
      'fallas',
      'marca_renovado',
      'marca',
      'medida',
      'modelo_renovado',
      'rango_carga',
      'sem_det',
      'sem_mstr',
      'tipo_unidad',
      'unidades'
    ];

    for (String table in tables) {
      final data = await db.query(table);
      logger.i("📊 Datos en $table: $data");
    }

    /// Llamamos a `syncData()` después de imprimir los datos de SQLite
    if (empresaId.isNotEmpty) {
      logger.i("🔄 Iniciando sincronización de datos desde la API...");
      await _authService.syncData(int.parse(empresaId), baseId, serie);
      logger.i("✅ Sincronización completada.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.amber,
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(height: 40),
                          Hero(
                            tag: 'logo',
                            child: Container(
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.rectangle,
                              ),
                              child: Image.asset(
                                'assets/logo.png',
                                height: 80,
                              ),
                            ),
                          ),
                          SizedBox(height: 20),
                          AnimatedTextKit(
                            animatedTexts: [
                              TypewriterAnimatedText(
                                'Bienvenido',
                                textStyle: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                speed: Duration(milliseconds: 500),
                              ),
                            ],
                            repeatForever: true,
                          ),
                          SizedBox(height: 30),
                          TextField(
                            controller: _usernameController,
                            onChanged: (value) {
                              _usernameController.value = TextEditingValue(
                                text: value.toUpperCase(),
                                selection: TextSelection.collapsed(
                                    offset: value.length),
                              );
                            },
                            decoration: InputDecoration(
                              labelText: 'Usuario',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                          ),
                          SizedBox(height: 15),
                          StatefulBuilder(
                            builder: (context, setState) {
                              return TextField(
                                controller: _passwordController,
                                onChanged: (value) {
                                  _passwordController.value = TextEditingValue(
                                    text: value.toUpperCase(),
                                    selection: TextSelection.collapsed(
                                        offset: value.length),
                                  );
                                },
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  labelText: 'Contraseña',
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                          SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: Text(
                              'Iniciar Sesión',
                              style: TextStyle(
                                color: Colors.amber,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Text(
                  _version,
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 10),
                    Text(
                      "Iniciando sesión...",
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

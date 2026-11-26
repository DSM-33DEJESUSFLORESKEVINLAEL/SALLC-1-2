// ignore_for_file: curly_braces_in_flow_control_structures, avoid_print

import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:miapp/db/db_crud.dart';
import 'package:miapp/db/opciontablas.dart';
import 'package:miapp/navigation/app_drawer.dart';
import 'package:miapp/screens/catalogo/marca/marca_register_screen.dart';
import 'package:miapp/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
// import 'package:sqflite/sqlite_api.dart';

class SemaforoRegisterScreen extends StatefulWidget {
  final Map<String, dynamic>? registroAEditar;

  const SemaforoRegisterScreen({super.key, this.registroAEditar});

  // const SemaforoRegisterScreen({super.key});

  @override
  State<SemaforoRegisterScreen> createState() => _SemaforoRegisterScreenState();
}

class _SemaforoRegisterScreenState extends State<SemaforoRegisterScreen> {
  bool _datosCargados = false;
  bool _yaGuardado = false;
  int? _numLlantasSeleccionadas; // 👈 esto arriba en tu `State`

  final FocusNode unidadFocusNode = FocusNode(); // En el State
  final FocusNode medidaTraseraFocusNode = FocusNode();

  final AuthService authService = AuthService();
  final TextEditingController folioController = TextEditingController();
  final TextEditingController mesController = TextEditingController();
  final TextEditingController anioController = TextEditingController();
  final TextEditingController usuarioController = TextEditingController();
  final TextEditingController unidadController = TextEditingController();
  final TextEditingController tipoUnidadController = TextEditingController();
  final TextEditingController medidaDireccionController =
      TextEditingController();
  final TextEditingController medidaTraseraController = TextEditingController();
  final TextEditingController observacionGeneralController =
      TextEditingController();
  final TextEditingController promedioController = TextEditingController();

  final int numPosiciones = 12;
  final List<TextEditingController> mmControllers =
      List.generate(12, (_) => TextEditingController());
  // final List<TextEditingController> orControllers = List.generate(12, (_) => TextEditingController());
  final List<String> orList = List.filled(12, "");
  final List<TextEditingController> dotControllers =
      List.generate(12, (_) => TextEditingController());
  final List<String> clasifMarcaList = List.filled(12, "");
  final List<String> observacionLlantaList =
      List.filled(12, ''); // <- en vez de "", pon un valor válido

  final List<String> orOptions = ['', 'O', 'R'];
  final List<String> clasifOptions = ['', 'PREMIUM', 'OTRAS'];
  final List<String> observacionOptions = [
    '',
    'CORTE COSTADO',
    'PERFORACION PISO',
    'PONCHADA',
    'DESGASTE IRREGULAR',
    'DESPRENDIMIENTO DE LA LLANTA',
    'IMPACTO CORTE PISO',
    'IMPACTO CORTE COSTADO',
    'IMPACTO CORTE HOMBRO',
    'SIN LLANTA',
    'SIN OBSERVACIONES'
  ];

  final Logger logger = Logger();
  String usuario = "";
  String empresa = "";
  String base = "";
  String operador = "";
  List<String> _opcionesUnidad = [];
  final List<String> _opcionesTipoUnidad = [];
  List<String> _opcionesMedida = [];
  Map<String, String> unidadTipoUnidadMap = {};
  Map<String, Map<String, dynamic>> unidadInfoMap = {}; // 👈 aquí en el state

  void _onItemTapped(int index) {
    setState(() {});
    Navigator.pop(context); // ✅ importante para cerrar el Drawer
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([]);
    _actualizarDatosEstadisticos();

    _cargarDatosIniciales().then((_) {
      if (widget.registroAEditar != null) {
        _precargarDatos(widget.registroAEditar!);
      }
    });
  }

  void _precargarDatos(Map<String, dynamic> data) {
    setState(() {
      folioController.text = data['folio'] ?? '';
      unidadController.text = data['unidad'] ?? '';
      tipoUnidadController.text = data['tunidad'] ?? '';
      medidaDireccionController.text = data['medida_direccion'] ?? '';
      medidaTraseraController.text = data['medida_trasera'] ?? '';
      observacionGeneralController.text = data['obs'] ?? '';

      for (int i = 0; i < numPosiciones; i++) {
        int pos = i + 1;
        mmControllers[i].text = data['mm$pos']?.toString() == 'null'
            ? ''
            : data['mm$pos']?.toString() ?? '';
        orList[i] = data['or$pos']?.toString() == 'null'
            ? ''
            : data['or$pos']?.toString() ?? '';
        dotControllers[i].text = data['dot$pos']?.toString() == 'null'
            ? ''
            : data['dot$pos']?.toString() ?? '';
        clasifMarcaList[i] = data['tmarca$pos']?.toString() == 'null'
            ? ''
            : data['tmarca$pos']?.toString() ?? '';
        observacionLlantaList[i] = data['obs$pos']?.toString() == 'null'
            ? ''
            : data['obs$pos']?.toString() ?? '';
      }
    });
  }

  Future<void> _cargarDatosIniciales() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userData = prefs.getString("userData");

    List<Map<String, dynamic>> unidadData =
        await DBOperations.instance.queryAllRows('unidades');
    List<Map<String, dynamic>> medidaData =
        await DBOperations.instance.queryAllRows('medida');

    String? folioGenerado;
    String? serie;

    if (userData != null) {
      Map<String, dynamic> user = jsonDecode(userData);
      usuario = user["USUARIO"] ?? "";
      empresa = user["EMPRESA"] ?? "";
      base = user["BASE"] ?? "";
      operador = user["OPERADOR"] ?? "";

      logger.i(
          "🏢 Empresa cargada: $empresa"); // 👈 Aquí se imprime en consola el número/nombre de empresa

      serie = await authService.obtenerSerieDesdeSQLite(empresa, base);
      folioGenerado = authService.obtenerFolio(serie);

      final unidadesValidas = await authService.getUnidadesDisponibles(
        empresa,
        base,
        folioGenerado,
      );

// ⚠️ Mostrar alerta solo si es NUEVO registro
      if (unidadesValidas.isEmpty && widget.registroAEditar == null) {
        if (mounted) {
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("⚠️ Sin unidades disponibles"),
              content: const Text(
                  "No hay unidades disponibles para este folio.\n\nPor favor, registra al menos una unidad para continuar."),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Aceptar"),
                ),
              ],
            ),
          );
        }
        return;
      }

      // ⚠️ Filtra solo las unidades válidas desde la lista total de unidadData
      unidadData = unidadData
          .where((item) =>
              unidadesValidas.contains(item['unidad'].toString().trim()))
          .toList();

      unidadInfoMap = {
        for (var item in unidadData)
          item['unidad'].toString(): {
            'tunidad': item['tunidad'] ?? item['TUNIDAD'],
            'num_llantas': item['num_llantas'] ??
                item['NUM_LLANTAS'] ??
                0, // 👈 Aquí el fix
          }
      };

      setState(() {
        if (folioGenerado != null) {
          folioController.text = folioGenerado;
        }
        //-----------------------------
        if (unidadController.text.isNotEmpty) {
          tipoUnidadController.text =
              unidadTipoUnidadMap[unidadController.text.trim()] ?? '';
        }
        //-----------------------------

        _opcionesUnidad = unidadData
            .map((data) => data['unidad']?.toString() ?? '')
            .where((e) => e.isNotEmpty)
            .toList();

        _opcionesMedida = medidaData
            .map((data) => data['medida']?.toString() ?? '')
            .where((e) => e.isNotEmpty)
            .toList();

        _datosCargados = true;
      });
    }
  }

  Future<Map<String, int>> _actualizarDatosEstadisticos() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString("userData");
    if (userData == null) return {};

    final Map<String, dynamic> user = jsonDecode(userData);
    int empRetiro =
        int.tryParse(user["DESMONTAJE_INMEDIATO"]?.toString() ?? "") ?? 0;
    int empProxInf =
        int.tryParse(user["DESMONTAJE_PROX_DESDE"]?.toString() ?? "") ?? 0;
    int empProxSup =
        int.tryParse(user["DESMONTAJE_PROX_HASTA"]?.toString() ?? "") ?? 0;
    int empBuenas =
        int.tryParse(user["BUENAS_CONDICIONES"]?.toString() ?? "") ?? 0;

    int sinLlanta = 0, sumaCero = 0, retiro = 0, proximoRetiro = 0;
    int buenas = 0, sumaO = 0, sumaR = 0, sumaMM = 0, nLlantas = 0;

    for (int i = 0; i < numPosiciones; i++) {
      final mmStr = mmControllers[i].text.trim();
      final obs = observacionLlantaList[i].trim();
      final or = orList[i].trim();

      final hasDatos = mmStr.isNotEmpty || obs.isNotEmpty;
      if (hasDatos) {
        nLlantas = i + 1;
        if (empresa == "1" && nLlantas > 8) {
          nLlantas = 8;
        }

        final mm = int.tryParse(mmStr) ?? -1;
        if (mm > 0) sumaMM += mm;

        if (obs.toUpperCase() == "SIN LLANTA") {
          sinLlanta++;
        } else {
          if (or == 'O') sumaO++;
          if (or == 'R') sumaR++;
        }

        if (mmStr == "0") {
          sumaCero++;
        } else if (mm != -1 && mm <= empRetiro) {
          retiro++;
        } else if (mm >= empProxInf && mm <= empProxSup) {
          proximoRetiro++;
        } else if (mm >= empBuenas) {
          buenas++;
        }
      }
    }

    int mmPromedio = nLlantas > 0 ? (sumaMM ~/ nLlantas) : 0;
    int edoUnidad = (sinLlanta > 0 || sumaCero > 0 || retiro > 0) ? 1 : 0;

    promedioController.text = mmPromedio.toString();

    logger.i("""
📊 Estadísticas calculadas:
  SIN_LLANTA: $sinLlanta
  CERO: $sumaCero
  RETIRO: $retiro
  PROX_RETIRO: $proximoRetiro
  BUENAS: $buenas
  ORIGINALES: $sumaO
  RENOVADAS: $sumaR
  NUM_LLANTAS: $nLlantas
  MM_SUMA: $sumaMM
  MM_PROMEDIO: $mmPromedio
  EDO_UNIDAD: $edoUnidad
""");

    return {
      "SIN_LLANTA": sinLlanta,
      "CERO": sumaCero,
      "RETIRO": retiro,
      "PROX_RETIRO": proximoRetiro,
      "BUENAS": buenas,
      "ORIGINALES": sumaO,
      "RENOVADAS": sumaR,
      "NUM_LLANTAS": nLlantas,
      "MM_SUMA": sumaMM,
      "MM_PROMEDIO": mmPromedio,
      "EDO_UNIDAD": edoUnidad,
    };
  }
// -----------------------------------------------------------

  Future<void> _actualizarunidades() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString("userData");
    if (userData == null) return;

    final user = jsonDecode(userData);
    final empresa = user["EMPRESA"] ?? "";
    final base = user["BASE"] ?? "";

    final serie = await authService.obtenerSerieDesdeSQLite(empresa, base);
    final folioGenerado = authService.obtenerFolio(serie);

    if (folioGenerado.isEmpty || folioGenerado == 'SIN_SERIE') {
      logger.e("❌ No se puede insertar en unidades porque folio es inválido");
      return;
    }

    // 🔍 Solo los nombres de unidades para validación rápida
    final unidadesValidas = await authService.getUnidadesDisponibles(
      empresa,
      base,
      folioGenerado,
    );

    // ⚠️ Mostrar alerta solo si es NUEVO registro
    if (unidadesValidas.isEmpty && widget.registroAEditar == null) {
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("⚠️ Sin unidades disponibles"),
            content: const Text(
                "No hay unidades disponibles para este folio.\n\nPor favor, registra al menos una unidad para continuar."),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("Aceptar"),
              ),
            ],
          ),
        );
      }
      return;
    }

    // 🧩 Obtener datos completos de las unidades válidas
    final unidadesData = await authService.getUnidadesDisponiblesFull(
      empresa,
      base,
      folioGenerado,
    );

    if (!mounted) return;

    // 🔎 Filtrar solo las que están en la lista de unidades válidas
    final unidadesFiltradas = unidadesData
        .where((item) =>
            unidadesValidas.contains(item['UNIDAD'].toString().trim()))
        .toList();

    logger.i("🏢 unidad cargada: $unidadesFiltradas");

    if (unidadesFiltradas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("⚠️ No hay unidades válidas para guardar.")),
      );
      return;
    }

    final db = await DatabaseHelper.instance.database;
    await db.delete('unidades');

    for (var unidad in unidadesFiltradas) {
      await db.insert(
        'unidades',
        {
          'empresa': unidad['EMPRESA'],
          'base': unidad['BASE'],
          'unidad': unidad['UNIDAD'],
          'folio': unidad['FOLIO'] ?? folioGenerado,
          'tunidad': unidad['TUNIDAD'],
          'obs': unidad['OBS'],
          'status': unidad['STATUS'],
          'ejes': unidad['EJES'],
          'num_llantas': unidad['NUM_LLANTAS'],
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    if (!mounted) return;
    setState(() {
      unidadController.text = '';
      tipoUnidadController.text = '';
      medidaDireccionController.text = '';
      medidaTraseraController.text = '';
      observacionGeneralController.text = '';
      for (var controller in mmControllers) {
        controller.clear();
      }
      for (var controller in dotControllers) {
        controller.clear();
      }
      for (int i = 0; i < orList.length; i++) {
        orList[i] = '';
      }
      for (int i = 0; i < clasifMarcaList.length; i++) {
        clasifMarcaList[i] = '';
      }
      for (int i = 0; i < observacionLlantaList.length; i++) {
        observacionLlantaList[i] = '';
      }

      _opcionesUnidad =
          unidadesFiltradas.map((e) => e['UNIDAD'].toString()).toList();

      unidadInfoMap = {
        for (var u in unidadesFiltradas)
          u['UNIDAD'].toString(): {
            'tunidad': u['TUNIDAD'],
            'num_llantas': u['NUM_LLANTAS'] ?? 0,
          }
      };
    });

    logger.i(
        "🔁 Unidades actualizadas y guardadas en SQLite: ${_opcionesUnidad.length}");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text("✅ Unidades sincronizadas con datos completos.")),
    );
  }

// -------------------------------------------------------------------

  void _handleSaveOrUpdateSemaforo() async {
    final stats = await _actualizarDatosEstadisticos();
    if (!mounted) return;
    if (empresa.isEmpty || folioController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Empresa o Folio no definidos")),
      );
      return;
    }

    if (!_opcionesUnidad.contains(unidadController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ La unidad seleccionada no es válida."),
        ),
      );
      return;
    }

    if (!_opcionesMedida.contains(medidaTraseraController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("⚠️ La medida trasera seleccionada no es válida.")),
      );
      return;
    }

    final isUpdate = _yaGuardado || widget.registroAEditar != null;

    String folio = folioController.text.trim();
    String fsistema = DateTime.now().toIso8601String().split("T")[0];

    int reg = (isUpdate && widget.registroAEditar != null)
        ? widget.registroAEditar!["reg"]
        : await DatabaseHelper.instance.getNextReg(folio, empresa, base);

    int nLlantas = stats["NUM_LLANTAS"] ?? 0;
    if (empresa == "1" && nLlantas > 8) {
      logger.i("📦 Empresa 1 detectada → NLLANTAS limitado a 8");
      nLlantas = 8;
    }

    Map<String, dynamic> mstrData = {
      "EMPRESA": empresa,
      "BASE": base,
      "FOLIO": folio,
      "FECHA": fsistema,
      "OPERADOR": operador,
      "NUM_SEMANA": DateTime.now().weekday,
      "NUM_MES": DateTime.now().month,
      // "NREGISTROS": stats["NUM_LLANTAS"],
      "NREGISTROS": nLlantas,
      "SIN_LLANTA": stats["SIN_LLANTA"],
      "CERO": stats["CERO"],
      "DESMONTAJE_INMEDIATO": stats["RETIRO"],
      "DESMONTAJE_PROXIMO": stats["PROX_RETIRO"],
      "BUENAS_CONDICIONES": stats["BUENAS"],
      // "LLANTAS_REVISADAS": stats["NUM_LLANTAS"],
      "LLANTAS_REVISADAS": nLlantas,
      "LLANTAS_ORIGINALES": stats["ORIGINALES"],
      "LLANTAS_RENOVADAS": stats["RENOVADAS"],
      "FSISTEMA": fsistema,
      "NUNIDADES": 1,
      // "NLLANTAS": stats["NUM_LLANTAS"],
      "NLLANTAS": nLlantas,
      "NOSEM_UNIDADES": 0,
      "NOSEM_LLANTAS": 0,
      "CIERRE_OPERADOR": null,
      "CIERRE_SUPERVISOR": null,
      "CIERRE_EMPRESA": null,
      "FCIERRE_OPERADOR": null,
      "FCIERRE_SUPERVISOR": null,
      "FCIERRE_EMPRESA": null,
    };

    final LinkedHashMap<String, dynamic> detData = LinkedHashMap();

    detData["FOLIO"] = folio;
    detData["USUARIO"] = usuario;
    detData["REG"] = reg;
    detData["UNIDAD"] = unidadController.text.trim();
    detData["TUNIDAD"] = tipoUnidadController.text.trim();
    detData["MEDIDA_DIRECCION"] = medidaDireccionController.text.trim();
    detData["MEDIDA_TRASERA"] = medidaTraseraController.text.trim();

    for (int i = 0; i < numPosiciones; i++) {
      int pos = i + 1;
      detData["MM$pos"] =
          mmControllers[i].text.isEmpty ? "null" : mmControllers[i].text;
      detData["OR$pos"] = orList[i].isEmpty ? "null" : orList[i];
      detData["OBS$pos"] =
          observacionLlantaList[i].isEmpty ? "null" : observacionLlantaList[i];
    }

    detData["OBS"] = observacionGeneralController.text.trim().isEmpty
        ? "null"
        : observacionGeneralController.text.trim();
    detData["SIN_LLANTA"] = stats["SIN_LLANTA"].toString();
    detData["CERO"] = stats["CERO"].toString();
    detData["RETIRO"] = stats["RETIRO"].toString();
    detData["PROX_RETIRO"] = stats["PROX_RETIRO"].toString();
    detData["BUENAS"] = stats["BUENAS"].toString();
    detData["ORIGINALES"] = stats["ORIGINALES"].toString();
    detData["RENOVADAS"] = stats["RENOVADAS"].toString();
    detData["NUM_LLANTAS"] =
        nLlantas.toString(); // ✅ usa el valor corregido (8)
    detData["MM_PROMEDIO"] = stats["MM_PROMEDIO"].toString();
    detData["MM_SUMA"] = stats["MM_SUMA"].toString();
    detData["FSISTEMA"] = fsistema;

    for (int i = 1; i <= 12; i++) {
      detData["TMARCA$i"] =
          clasifMarcaList[i - 1].isEmpty ? "null" : clasifMarcaList[i - 1];
    }
    for (int i = 1; i <= 12; i++) {
      detData["DOT$i"] = dotControllers[i - 1].text.isEmpty
          ? "null"
          : dotControllers[i - 1].text;
    }
    detData["EDO_UNIDAD"] = stats["EDO_UNIDAD"].toString();
    for (int i = 1; i <= 12; i++) {
      detData["BIT$i"] = "null";
    }

    detData["EMPRESA"] = empresa;
    detData["BASE"] = base;
    detData["VERSION"] = "C1806";

    final hasInternet = await AuthService().hasInternetConnection();
    final url = Uri.parse(
        "http://atlastoluca.dyndns.org:20100/datasnap/rest/TServerMethods1/Semaforeo");
    try {
      http.Response response;

      if (hasInternet) {
        if (isUpdate) {
          response = await http.put(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(detData),
          );
          // logger.i("🔁 Enviando UPDATE (PUT) -> $url");
          // logger.i("🔁 PUT enviado:\n${jsonEncode(detData)}");
          logger.i("🔁 Enviando UPDATE (PUT) -> $url");
          logger.i(
              "🔁 PUT enviado COMPLETO:\n${const JsonEncoder.withIndent('  ').convert(detData)}");
        } else {
          response = await http.post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(detData),
          );
          // logger.i("📤 POST enviado:\n${jsonEncode(detData)}");
          logger.i(
              "📤 POST enviado COMPLETO:\n${const JsonEncoder.withIndent('  ').convert(detData)}");
        }

        if ((isUpdate && response.statusCode == 201) ||
            (!isUpdate && response.statusCode == 200)) {
          logger.i("✅ Respuesta OK -> ${response.statusCode}");
          detData['sincronizado'] = 1;

          if (isUpdate) {
            await DBOperations.instance.update(
                'sem_det', detData, 'folio = ? AND reg = ?', [folio, reg]);
            await DBOperations.instance
                .update('sem_mstr', mstrData, 'folio = ?', [folio]);
          } else {
            await DBOperations.instance.insert('sem_mstr', mstrData);
            await DBOperations.instance.insert('sem_det', detData);
          }

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isUpdate
                ? "✅ Registro actualizado correctamente."
                : "✅ Registro guardado correctamente."),
          ));

          _yaGuardado = true; // importante: ya fue guardado
        } else {
          logger.w("⚠️ Error del servidor: ${response.body}");
          await _guardarLocal(mstrData, detData, folio,
              mensaje: "Guardado local por error en servidor.");
        }
      } else {
        await _guardarLocal(mstrData, detData, folio,
            mensaje: "📦 Guardado sin conexión.");
        _yaGuardado = true;
      }
    } catch (e) {
      logger.e("❌ Error de conexión: $e");
      await _guardarLocal(mstrData, detData, folio,
          mensaje: "Guardado local por fallo de conexión.");
      _yaGuardado = true;
    }
  }

  Future<void> _guardarLocal(
    Map<String, dynamic> mstr,
    Map<String, dynamic> det,
    String folio, {
    required String mensaje,
  }) async {
    try {
      print("🔹 sem_mstr: $mstr");
      print("🔸 sem_det: $det");

      final isUpdate = widget.registroAEditar != null;

      if (isUpdate) {
        // 🔁 Actualiza si ya existe
        await DBOperations.instance.update(
          'sem_mstr',
          mstr,
          'folio = ?',
          [folio],
        );
        await DBOperations.instance.update(
          'sem_det',
          det,
          'folio = ? AND reg = ?',
          [folio, det['REG']],
        );
      } else {
        // ➕ Inserta si es nuevo
        await DBOperations.instance.insert('sem_mstr', mstr);
        await DBOperations.instance.insert('sem_det', det);
      }

      logger.i("💾 Guardado local exitoso.");
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(mensaje)));

      // _limpiarFormulario(); // <-- limpia el formulario
    } catch (e) {
      logger.e("❌ Error al guardar localmente: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Error al guardar en SQLite.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(onSelectItem: _onItemTapped),
      appBar: AppBar(
        title: const Text("Captura Semáforeo"),
        actions: [
          IconButton(
            tooltip: "Actualizar Unidades",
            icon: const Icon(Icons.replay_circle_filled_sharp),
            // onPressed: _actualizarunidades,
            onPressed: () async {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) {
                  return const AlertDialog(
                    content: Row(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 20),
                        Text("Actualizando unidades..."),
                      ],
                    ),
                  );
                },
              );

              await _actualizarunidades(); // llama la función completa

              if (context.mounted)
                Navigator.of(context).pop(); // cierra el modal
            },
          ),
          IconButton(
            tooltip: "Guardar semáforo",
            icon: const Icon(Icons.check),
            onPressed: _handleSaveOrUpdateSemaforo,
          ),
        ],
      ),
      body: !_datosCargados
          ? const Center(
              child: CircularProgressIndicator()) // <- Espera a que se cargue
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopFields(),
                  const Divider(),
                  _buildLlantaTable(),
                  const Divider(),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: observacionGeneralController,
                          decoration:
                              const InputDecoration(labelText: 'Observación'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text("Promedio:"),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 60,
                        child: TextField(
                          controller: promedioController,
                          enabled: false,
                          decoration: const InputDecoration(),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildTopFields() {
    bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Column(
      children: [
        Row(
          children: [
            _buildReadOnlyTextField(folioController, "Folio"),
            _buildReadOnlyTextField(usuarioController, usuario),
          ],
        ),
        isLandscape
            ? Row(
                children: [
                  _buildUnidadDropdown(
                      unidadController, "Unidad", _opcionesUnidad),
                  _buildDropdownField(tipoUnidadController, "Tipo de unidad",
                      _opcionesTipoUnidad),
                  _buildMedidaDireccionDropdown(),
                  _buildDropdownField(medidaTraseraController, "Medida trasera",
                      _opcionesMedida),
                ],
              )
            : Column(
                children: [
                  Row(
                    children: [
                      _buildUnidadDropdown(
                          unidadController, "Unidad", _opcionesUnidad),
                      _buildDropdownField(tipoUnidadController,
                          "Tipo de unidad", _opcionesTipoUnidad),
                    ],
                  ),
                  Row(
                    children: [
                      _buildMedidaDireccionDropdown(),
                      _buildDropdownField(medidaTraseraController,
                          "Medida trasera", _opcionesMedida),
                    ],
                  ),
                ],
              ),
      ],
    );
  }

  Widget _buildUnidadDropdown(
      TextEditingController controller, String label, List<String> opciones) {
    List<String> opcionesFiltradas = opciones.toSet().toList();

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: TypeAheadField<String>(
          controller: controller,
          builder: (context, fieldController, focusNode) => TextFormField(
            controller: fieldController,
            focusNode: focusNode,
            decoration: InputDecoration(
              labelText: label,
              suffixIcon: const Icon(Icons.arrow_drop_down),
            ),
            validator: (value) {
              if (value == null || !_opcionesUnidad.contains(value.trim())) {
                return "Unidad no válida";
              }
              return null;
            },
            onSaved: (_) {
              final unidad = controller.text.trim();
              if (!_opcionesUnidad.contains(unidad)) {
                controller.clear();
                tipoUnidadController.clear();
              } else {
                tipoUnidadController.text = unidadTipoUnidadMap[unidad] ?? '';
              }
            },
          ),
          suggestionsCallback: (pattern) {
            // Si el campo está vacío, muestra todas las sugerencias
            if (pattern.isEmpty) return opcionesFiltradas;

            // Si se está escribiendo, filtra por coincidencias
            return opcionesFiltradas
                .where((item) =>
                    item.toLowerCase().contains(pattern.toLowerCase()))
                .toList();
          },
          itemBuilder: (context, String suggestion) {
            return ListTile(title: Text(suggestion));
          },
          onSelected: (String suggestion) {
            setState(() {
              controller.text = suggestion;
              // tipoUnidadController.text = unidadTipoUnidadMap[suggestion] ?? '';
              tipoUnidadController.text =
                  unidadInfoMap[suggestion]?['tunidad']?.toString() ?? '';
              // _numLlantasSeleccionadas = int.tryParse(
              //     unidadInfoMap[suggestion]?['num_llantas']?.toString() ?? '');
              _numLlantasSeleccionadas = int.tryParse(
                      unidadInfoMap[suggestion]?['num_llantas']?.toString() ??
                          '') ??
                  0;

              logger.i(
                  "🛞 Unidad seleccionada con $_numLlantasSeleccionadas llantas");
            });
          },

          emptyBuilder: (context) => const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text("No se encontraron coincidencias"),
          ),

          // onSaved: (_) {
          //   String unidad = controller.text.trim();
          //   if (!_opcionesUnidad.contains(unidad)) {
          //     controller.clear();
          //     tipoUnidadController.clear();
          //   } else {
          //     tipoUnidadController.text = unidadTipoUnidadMap[unidad] ?? '';
          //   }
          // }
        ),
      ),
    );
  }

  Widget _buildDropdownField(
      TextEditingController controller, String label, List<String> opciones) {
    List<String> opcionesFiltradas =
        opciones.toSet().toList(); // Quita duplicados

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: TypeAheadField<String>(
          controller: controller,
          builder: (context, fieldController, focusNode) => TextFormField(
            controller: fieldController,
            focusNode: focusNode,
            inputFormatters: [
              UpperCaseTextFormatter(), // 👈 aquí se aplica
            ],
            decoration: InputDecoration(
              labelText: label,
              suffixIcon:
                  const Icon(Icons.arrow_drop_down), // 🔽 Ícono de combo
            ),
          ),
          // suggestionsCallback: (pattern) {
          //   return opcionesFiltradas
          //       .where((item) =>
          //           item.toLowerCase().contains(pattern.toLowerCase()))
          //       .toList();
          // },
          suggestionsCallback: (pattern) {
            return opcionesFiltradas
                .where((item) => item
                    .toUpperCase()
                    .contains(pattern.toUpperCase())) // ✅ corregido
                .toList();
          },

          itemBuilder: (context, String suggestion) {
            return ListTile(
              title: Text(suggestion),
            );
          },
          onSelected: (String suggestion) {
            setState(() {
              controller.text = suggestion;
            });
          },
          emptyBuilder: (context) => const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text("No se encontraron coincidencias"),
          ),
        ),
      ),
    );
  }

  Widget _buildReadOnlyTextField(
      TextEditingController controller, String label) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade200, // Fondo gris claro
            borderRadius: BorderRadius.circular(8), // Bordes redondeados
            border: Border.all(color: Colors.grey.shade400), // Borde suave
          ),
          child: TextField(
            controller: controller,
            enabled: false, // No editable
            readOnly: true, // Seguridad extra
            style: const TextStyle(
              color: Colors.black, // Texto negro
              fontWeight: FontWeight.bold, // Texto más grueso
              fontSize: 16, // Tamaño opcional
            ),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(
                color: Colors.grey.shade700, // Color del label
              ),
              border: InputBorder.none, // Quitamos borde interno
              contentPadding: const EdgeInsets.symmetric(
                vertical: 8,
                horizontal: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLlantaTable() {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    if (isLandscape) {
      // MODO HORIZONTAL: como lo tienes, tipo tabla horizontal
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezados
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: const [
                SizedBox(
                    width: 40,
                    child: Text("Pos",
                        style: TextStyle(fontWeight: FontWeight.bold))),
                SizedBox(
                    width: 50,
                    child: Text("MM",
                        style: TextStyle(fontWeight: FontWeight.bold))),
                SizedBox(
                    width: 50,
                    child: Text("  O/R",
                        style: TextStyle(fontWeight: FontWeight.bold))),
                SizedBox(
                    width: 60,
                    child: Text("      DOT",
                        style: TextStyle(fontWeight: FontWeight.bold))),
                SizedBox(
                    width: 130,
                    child: Text("        Clasif. marca",
                        style: TextStyle(fontWeight: FontWeight.bold))),
                SizedBox(
                    width: 180,
                    child: Text("        Observación por llanta",
                        style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          const SizedBox(height: 8),

          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: numPosiciones,
            itemBuilder: (context, index) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(width: 40, child: Text("${index + 1}")),
                      _buildSizedField(mmControllers[index], 50),
                      _buildDropdown(index, orList, orOptions, 55),
                      _buildSizedField(dotControllers[index], 60),
                      _buildDropdown(
                          index, clasifMarcaList, clasifOptions, 130),
                      _buildDropdown(index, observacionLlantaList,
                          observacionOptions, 180),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      );
    } else {
      // MODO VERTICAL: diseño en "tarjeta" por llanta (2 en pantalla aprox)
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Detalle por llanta",
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
//---------------------- LLANTAS----------------------------------

          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            // itemCount: numPosiciones,
            itemCount: _numLlantasSeleccionadas ?? numPosiciones,
            itemBuilder: (context, index) {
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Llanta ${index + 1}",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                              child: _buildSizedField(
                                  mmControllers[index], double.infinity,
                                  label: "MM")),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _buildDropdown(
                                  index, orList, orOptions, double.infinity,
                                  label: "O/R")),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                              child: _buildSizedField(
                                  dotControllers[index], double.infinity,
                                  label: "DOT")),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _buildDropdown(index, clasifMarcaList,
                                  clasifOptions, double.infinity,
                                  label: "Clasif. marca")),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildDropdown(index, observacionLlantaList,
                          observacionOptions, double.infinity,
                          label: "Observación"),
                    ],
                  ),
                ),
              );
            },

//--------------------------------------------------------
          ),
        ],
      );
    }
  }

  Widget _buildSizedField(TextEditingController controller, double width,
      {String? label}) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.digitsOnly,
        ],
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.all(8),
        ),
      ),
    );
  }

  Widget _buildDropdown(
      int index, List<String> valueList, List<String> options, double width,
      {String? label}) {
    String currentValue = valueList[index];
    if (!options.contains(currentValue)) {
      currentValue = options.first;
      valueList[index] = currentValue;
    }

    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        value: currentValue,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.all(8),
        ),
        onChanged: (value) {
          if (value != null) {
            setState(() {
              valueList[index] = value;
            });
          }
        },
        items: options.map((val) {
          return DropdownMenuItem<String>(
            value: val,
            child: Text(val, overflow: TextOverflow.ellipsis),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMedidaDireccionDropdown() {
    List<String> opcionesFiltradas =
        _opcionesMedida.toSet().toList(); // Quitar duplicados

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: TypeAheadField<String>(
          controller: medidaDireccionController,
          builder: (context, fieldController, focusNode) => TextFormField(
            controller: fieldController,
            focusNode: focusNode,
            decoration: const InputDecoration(
              labelText: "Medida dirección",
              suffixIcon: Icon(Icons.arrow_drop_down),
            ),
          ),
          suggestionsCallback: (pattern) {
            return opcionesFiltradas
                .where((item) =>
                    item.toLowerCase().contains(pattern.toLowerCase()))
                .toList();
          },
          itemBuilder: (context, String suggestion) {
            return ListTile(title: Text(suggestion));
          },
          onSelected: (String suggestion) {
            setState(() {
              medidaDireccionController.text = suggestion;
              // ✅ Copiar valor a medida trasera por defecto
              if (medidaTraseraController.text.trim().isEmpty) {
                medidaTraseraController.text = suggestion;
              }
            });
          },
          emptyBuilder: (context) => const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text("No se encontraron coincidencias"),
          ),
        ),
      ),
    );
  }
}

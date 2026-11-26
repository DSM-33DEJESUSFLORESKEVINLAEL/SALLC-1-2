// © 2025 Kevin Lael de Jesús Flores
// Todos los derechos reservados.
// Este código es parte de la aplicación [Mi app].
// Prohibida su reproducción o distribución sin autorización.

// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:logger/logger.dart';
import 'package:miapp/db/db_crud.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:miapp/models/desdet.dart';
// import 'package:miapp/models/desmstr.dart';
import 'package:miapp/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
// import 'package:sqflite/sqflite.dart';

class PilaRegisterMtrScreen extends StatefulWidget {
  final String folio;
  final bool nuevoFolio;
  final String? folioExistente;
  final DesDet? desdet; // 👈 Nuevo parámetro

  const PilaRegisterMtrScreen({
    required this.folio,
    super.key,
    required this.nuevoFolio,
    this.folioExistente,
    this.desdet,
  });

  @override
  PilaRegisterMtrScreenState createState() => PilaRegisterMtrScreenState();
}

class PilaRegisterMtrScreenState extends State<PilaRegisterMtrScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _folioController = TextEditingController();
  final TextEditingController _marcaController = TextEditingController();
  final TextEditingController _medidaController = TextEditingController();
  final TextEditingController _rangocargaController = TextEditingController();
  final TextEditingController _marcaRenovadoraController =
      TextEditingController();
  final TextEditingController _modeloRenovadoraController =
      TextEditingController();
  final TextEditingController _unidadController = TextEditingController();
  final TextEditingController _modeloController = TextEditingController();
  final TextEditingController _serieController = TextEditingController();
  final TextEditingController _dotController = TextEditingController();
  final TextEditingController _pisoRemanenteController =
      TextEditingController();

  List<String> _opcionesMarca = [];
  List<String> _opcionesMedida = [];
  List<String> _opcionesRangoCarga = [];
  List<String> _opcionesMarcaRenovadora = [];
  List<String> _opcionesModeloRenovadora = [];
  List<String> _opcionesFallas = []; // Agregar esta línea

  String? _selectedOriginalRenovada;
  String? _selectedSistemaMedida;
  final List<String?> _fallas = List.filled(5, null);
  final List<String> opcionesSistemaMedida = ['mm', '32"'];
  final List<String> opcionesOriginalRenovada = [
    'OR',
    'RNC',
    'RN1',
    'RN2',
    'RN3',
    'RN4'
  ];
  late AnimationController _animationController;

  final Logger logger = Logger();
  bool _botonDeshabilitado = false;
  // bool _datosCargados = false;
  String usuario = "";
  String empresa = "";
  String base = "";
  String operador = "";
  String? _selectedSemanaDOT;
  String? _selectedAnioDOT;

//--------------------------------- VALIDACIONES----------------------------------------------------

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  bool _esValorValido(String valor, List<String> lista) {
    return lista.contains(valor.trim());
  }

  bool _validarCamposObligatorios() {
    if (_folioController.text.trim().isEmpty) {
      _mostrarError("El campo FOLIO es obligatorio.");
      return false;
    }

    if (_marcaController.text.trim().isEmpty) {
      _mostrarError("La MARCA es obligatoria.");
      return false;
    }
    if (_modeloController.text.trim().isEmpty) {
      _mostrarError("El MODELO es obligatorio.");
      return false;
    }
    if (_medidaController.text.trim().isEmpty) {
      _mostrarError("La MEDIDA es obligatoria.");
      return false;
    }
    if (_pisoRemanenteController.text.trim().isEmpty ||
        int.tryParse(_pisoRemanenteController.text.trim()) == null) {
      _mostrarError("El PISO REMANENTE es obligatorio y debe ser un número.");
      return false;
    }
    if (_rangocargaController.text.trim().isEmpty) {
      _mostrarError("El RANGO DE CARGA es obligatorio.");
      return false;
    }
    if (_selectedOriginalRenovada == null) {
      _mostrarError("Debes seleccionar si la llanta es ORIGINAL o RENOVADA.");
      return false;
    }
    if (_selectedSistemaMedida == null) {
      _mostrarError("Debes seleccionar el SISTEMA DE MEDIDA.");
      return false;
    }

    // 🔒 Validar que los valores estén en las listas válidas
    if (!_esValorValido(_marcaController.text, _opcionesMarca)) {
      _mostrarError("La MARCA seleccionada no es válida.");
      return false;
    }
    if (!_esValorValido(_medidaController.text, _opcionesMedida)) {
      _mostrarError("La MEDIDA seleccionada no es válida.");
      return false;
    }
    if (!_esValorValido(_rangocargaController.text, _opcionesRangoCarga)) {
      _mostrarError("El RANGO DE CARGA seleccionado no es válido.");
      return false;
    }
    if (_marcaRenovadoraController.text.trim().isNotEmpty &&
        !_esValorValido(
            _marcaRenovadoraController.text, _opcionesMarcaRenovadora)) {
      _mostrarError("La MARCA RENOVADORA seleccionada no es válida.");
      return false;
    }
    if (_modeloRenovadoraController.text.trim().isNotEmpty &&
        !_esValorValido(
            _modeloRenovadoraController.text, _opcionesModeloRenovadora)) {
      _mostrarError("El MODELO RENOVADOR seleccionado no es válido.");
      return false;
    }

    for (int i = 0; i < _fallas.length; i++) {
      final falla = _fallas[i];
      if (falla != null &&
          falla != "null" &&
          !_opcionesFallas.any((f) => f.startsWith(falla))) {
        _mostrarError("La FALLA ${i + 1} no es válida.");
        return false;
      }
    }

    return true;
  }

  @override
  void initState() {
    super.initState();
    _folioController.text = widget.folio;

    if (!widget.nuevoFolio && widget.folioExistente != null) {
      _folioController.text = widget.folioExistente!;
    }

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _cargarDatosIniciales().then((_) {
      if (widget.desdet != null) {
        final d = widget.desdet!;
        setState(() {
          _unidadController.text = d.procedencia ?? '';
          _marcaController.text = d.marca ?? '';
          _modeloController.text = d.modelo ?? '';
          _medidaController.text = d.medida ?? '';
          _pisoRemanenteController.text = d.pisoRemanente?.toString() ?? '';
          _rangocargaController.text = d.rangoCarga ?? '';
          _selectedOriginalRenovada = d.oriren?.toString();
          _marcaRenovadoraController.text = d.marcaRen ?? '';
          _modeloRenovadoraController.text = d.modeloRen ?? '';
          _serieController.text = d.serie ?? '';
          _dotController.text = d.dot ?? '';
          _selectedSistemaMedida = d.sisMedida;

          _fallas[0] = d.falla1;
          _fallas[1] = d.falla2;
          _fallas[2] = d.falla3;
          _fallas[3] = d.falla4;
          _fallas[4] = d.falla5;
        });
      }
      _animationController.forward();
    });
  }

  Future<void> _cargarDatosIniciales() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userData = prefs.getString("userData");

    List<Map<String, dynamic>> marcasData =
        await DBOperations.instance.queryAllRows('marca');
    List<Map<String, dynamic>> medidaData =
        await DBOperations.instance.queryAllRows('medida');
    List<Map<String, dynamic>> rangoCargaData =
        await DBOperations.instance.queryAllRows('rango_carga');
    List<Map<String, dynamic>> marcaRenData =
        await DBOperations.instance.queryAllRows('marca_renovado');
    List<Map<String, dynamic>> modeloRenData =
        await DBOperations.instance.queryAllRows('modelo_renovado');
    List<Map<String, dynamic>> fallaData =
        await DBOperations.instance.queryAllRows('fallas');

    String? folioGenerado;
    String? serie;

    if (userData != null) {
      Map<String, dynamic> user = jsonDecode(userData);
      usuario = user["USUARIO"] ?? "";
      empresa = user["EMPRESA"] ?? "";
      base = user["BASE"] ?? "";
      operador = user["OPERADOR"] ?? "";

      // ✅ Obtener serie y folio generado
      serie = await AuthService().obtenerSerieDesdeSQLite(empresa, base);
      folioGenerado = AuthService().obtenerFolio(serie);

      // ✅ Asignar el folio solo si es nuevo (no estamos editando)
      if (widget.desdet == null) {
        _folioController.text = folioGenerado;
      }
    }

    setState(() {
      _opcionesMarca = marcasData
          .map((data) => data['marca']?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();

      _opcionesMedida = medidaData
          .map((data) => data['medida']?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();

      _opcionesRangoCarga = rangoCargaData
          .map((data) => data['rc']?.toString() ?? '')
          .where((item) => item.isNotEmpty)
          .toList();

      _opcionesMarcaRenovadora = marcaRenData
          .map((data) => data['marca']?.toString() ?? '')
          .where((item) => item.isNotEmpty)
          .toList();

      _opcionesModeloRenovadora = modeloRenData
          .map((data) => data['modelo']?.toString() ?? '')
          .where((item) => item.isNotEmpty)
          .toList();

      _opcionesFallas = fallaData
          .map((data) {
            String falla = data['falla']?.toString() ?? 'Sin nombre';
            String descripcion =
                data['descripcion']?.toString() ?? 'Sin descripción';
            return "$falla - $descripcion";
          })
          .where((item) => item.isNotEmpty)
          .toList();

      // Refrescar campos por si ya tenían valores escritos
      _marcaController.text = _marcaController.text.toUpperCase();
      _medidaController.text = _medidaController.text.toUpperCase();
      _rangocargaController.text = _rangocargaController.text.toUpperCase();
    });
  }

  Future<void> _handleSaveOrUpdate() async {
    if (!_validarCamposObligatorios()) return;

    if (empresa.isEmpty || base.isEmpty) {
      _mostrarError("⚠️ Empresa o Base no está definido.");
      return;
    }

    final folio = _folioController.text.trim();
    final operadorValor = usuario.trim();
    // ignore: unused_local_variable
    final fsistema = DateTime.now().toIso8601String().split('T')[0];
    final sistemaMedida = _selectedSistemaMedida?.trim() ?? "null";

    int regInt = widget.desdet?.reg ??
        await DBOperations.instance.getSiguienteRegParaFolio(folio);

    Map<String, dynamic> newRegistro = {
      "FOLIO": folio,
      "REG": regInt.toString(),
      "PROCEDENCIA": _unidadController.text.trim().isEmpty
          ? "null"
          : _unidadController.text.trim(),
      "MARCA": _marcaController.text.trim().isEmpty
          ? "null"
          : _marcaController.text.trim(),
      "MODELO": _modeloController.text.trim().isEmpty
          ? "null"
          : _modeloController.text.trim(),
      "MEDIDA": _medidaController.text.trim().isEmpty
          ? "null"
          : _medidaController.text.trim(),
      "PISO_REMANENTE": _pisoRemanenteController.text.trim().isEmpty
          ? "null"
          : _pisoRemanenteController.text.trim(),
      "RANGO_CARGA": _rangocargaController.text.trim().isEmpty
          ? "null"
          : _rangocargaController.text.trim(),
      "ORIREN": _selectedOriginalRenovada?.trim().isEmpty ?? true
          ? "null"
          : _selectedOriginalRenovada!.trim(),
      "MARCA_REN": _marcaRenovadoraController.text.trim().isEmpty
          ? "null"
          : _marcaRenovadoraController.text.trim(),
      "MODELO_REN": _modeloRenovadoraController.text.trim().isEmpty
          ? "null"
          : _modeloRenovadoraController.text.trim(),
      "SERIE": _serieController.text.trim().isEmpty
          ? "null"
          : _serieController.text.trim(),
      "DOT": _dotController.text.trim().isEmpty
          ? "null"
          : _dotController.text.trim(),
      "FALLA1":
          _fallas[0]?.trim().isEmpty ?? true ? "null" : _fallas[0]!.trim(),
      "FALLA2":
          _fallas[1]?.trim().isEmpty ?? true ? "null" : _fallas[1]!.trim(),
      "FALLA3":
          _fallas[2]?.trim().isEmpty ?? true ? "null" : _fallas[2]!.trim(),
      "FALLA4":
          _fallas[3]?.trim().isEmpty ?? true ? "null" : _fallas[3]!.trim(),
      "FALLA5":
          _fallas[4]?.trim().isEmpty ?? true ? "null" : _fallas[4]!.trim(),
      // "ANIO": DateTime.now().year.toString(),
      "ANIO": _selectedAnioDOT != null
          ? _selectedAnioDOT!.substring(2, 4).padLeft(2, '0')
          : "null",
      "FSISTEMA":
          DateTime.now().toIso8601String(), // formato completo ISO con hora
      "VERSION": "C1806",
      "EMPRESA": empresa.toString(),
      "BASE": base,
      "SIS_MEDIDA": sistemaMedida,
      "OPERADOR": operadorValor,
    };

    final hasInternet = await AuthService().hasInternetConnection();

    if (!hasInternet) {
      final registroOffline = {...newRegistro, "SINCRONIZADO": 0};

      await DBOperations.instance.insert2(
        'desdet',
        registroOffline,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("📦 Guardado localmente (sin conexión)")),
      );
      Navigator.pop(context, folio);
      return;
    }

    try {
      final url = Uri.parse(
          "http://atlastoluca.dyndns.org:20100/datasnap/rest/TServerMethods1/PilaDesecho");
      http.Response response;

      final isUpdate = widget.desdet != null;

      if (isUpdate) {
        // print("📤 Enviando PUT con JSON:\n${jsonEncode(newRegistro)}");

        response = await http.put(
          url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(newRegistro), // 👈 JSON plano, como espera Delphi
        );

        // print("🔁 PUT respuesta: ${response.body}");
      } else {
        // POST: Nuevo en servidor
        response = await http.post(
          url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(newRegistro),
        );
      }

      if ((isUpdate && response.statusCode == 201) ||
          (!isUpdate && response.statusCode == 200)) {
        final registroOnline = {...newRegistro, "SINCRONIZADO": 1};

        await DBOperations.instance.insert2(
          'desdet',
          registroOnline,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isUpdate
                ? "✅ Registro actualizado correctamente."
                : "✅ Registro guardado correctamente."),
          ),
        );
        Navigator.pop(context, folio);
      } else {
        _mostrarError(
            "❌ Error al ${isUpdate ? 'actualizar' : 'guardar'}: Código ${response.statusCode}");
      }
    } catch (e) {
      _mostrarError("❌ Error de conexión: $e");
    }
  }

//------------------------INICIO DEL FORMULARIO--------------------------------------

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        primarySwatch: Colors.amber,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.amber[50],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Registrar Pila de Desecho"),
          backgroundColor: Colors.amber,
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildAnimatedField1(
                "Folio", _folioController, FontAwesomeIcons.fileAlt),
            _buildAnimatedDropdown("Sistema de Medida", opcionesSistemaMedida,
                _selectedSistemaMedida, (value) {
              setState(() => _selectedSistemaMedida = value);
            }),
            _buildSectionTitle("Datos de la unidad"),
            _buildAnimatedField(
                "Unidad", _unidadController, FontAwesomeIcons.truck),
            _buildTypeAheadField(
                "Marca", _opcionesMarca, _marcaController, (value) {}),
            _buildAnimatedField(
                "Modelo", _modeloController, FontAwesomeIcons.car),
            _buildTypeAheadField(
                "Medida", _opcionesMedida, _medidaController, (value) {}),
            _buildAnimatedIntFieldd("Piso Remanente", _pisoRemanenteController,
                FontAwesomeIcons.layerGroup),
            _buildTypeAheadField("Rango de Carga", _opcionesRangoCarga,
                _rangocargaController, (value) {}),
            _buildSectionTitle("Datos de renovación"),
            _buildAnimatedDropdown("Original/Renovada",
                opcionesOriginalRenovada, _selectedOriginalRenovada, (value) {
              setState(() => _selectedOriginalRenovada = value);
            }),
            _buildTypeAheadField(
                "Marca de Renovadora",
                _opcionesMarcaRenovadora,
                _marcaRenovadoraController,
                (value) {}),
            _buildTypeAheadField(
                "Modelo de Renovado",
                _opcionesModeloRenovadora,
                _modeloRenovadoraController,
                (value) {}),
            _buildAnimatedField(
                "Serie/Económico", _serieController, FontAwesomeIcons.tag),

            _buildDOTSemanaAnioField(
                "DOT", _dotController, FontAwesomeIcons.infoCircle),
            _buildSectionTitle("Fallas"),

            for (int i = 0; i < 5; i++)
              _buildAnimatedDropdown(
                  "Falla ${i + 1}", _opcionesFallas, _fallas[i], (value) {
                setState(() => _fallas[i] = value);
              }),
            //BOTON DE ACEPTAR
            Center(
              child: ElevatedButton(
                onPressed: _botonDeshabilitado
                    ? null
                    : () async {
                        setState(() => _botonDeshabilitado = true);
                        await _handleSaveOrUpdate(); // ✅ con guion bajo
                        setState(() => _botonDeshabilitado = false);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  padding: const EdgeInsets.symmetric(
                      vertical: 7.0, horizontal: 40.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  "Aceptar",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            //FIN DEL BOTON DE ACEPTAR
          ],
        ),
      ),
    );
  }

//-----------------------FUNCIONES DEL INPUTS DATOS ESTATICOS--------------------------------
  Widget _buildAnimatedField1(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        enabled: false, // No editable
        onChanged: (value) {
          final upper = value.toUpperCase();
          if (value != upper) {
            controller.value = controller.value.copyWith(
              text: upper,
              selection: TextSelection.collapsed(offset: upper.length),
            );
          }
        },
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.blueGrey[700]),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildAnimatedField(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        onChanged: (value) {
          final upper = value.toUpperCase();
          if (value != upper) {
            controller.value = controller.value.copyWith(
              text: upper,
              selection: TextSelection.collapsed(offset: upper.length),
            );
          }
        },
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.blueGrey[700]),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildAnimatedIntFieldd(
      String label, TextEditingController controller, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number, // Solo permite números
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.blueGrey[700]),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

//----------------------- FIN DE FUNCIONES DEL INPUTS DATOS DE ESTATICOS-------------------------------
//-----------------------FUNCIONES DEL INPUTS DATOS DE OTRAS TABLAS--------------------------------

  Widget _buildTypeAheadField(
    String label,
    List<String> items,
    TextEditingController controller,
    Function(String) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TypeAheadField<String>(
        controller: controller,
        builder: (context, fieldController, focusNode) => TextFormField(
          controller: fieldController,
          focusNode: focusNode,
          onChanged: (value) {
            controller.value = controller.value.copyWith(
              text: value.toUpperCase(), // Mayúsculas mientras escribe
              selection: TextSelection.collapsed(offset: value.length),
            );
          },
          onEditingComplete: () {
            String currentText = controller.text.trim().toUpperCase();
            bool exists =
                items.any((item) => item.toUpperCase() == currentText);

            if (exists) {
              controller.text = currentText; // Lo deja en mayúsculas
              onChanged(currentText);
            } else {
              controller.clear(); // Lo limpia si no coincide
              onChanged('');
            }
          },
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
          ),
        ),
        suggestionsCallback: (pattern) {
          return items
              .where(
                  (item) => item.toLowerCase().contains(pattern.toLowerCase()))
              .toList();
        },
        itemBuilder: (context, suggestion) {
          return ListTile(title: Text(suggestion));
        },
        onSelected: (suggestion) {
          controller.text = suggestion.toUpperCase(); // Guarda en mayúsculas
          onChanged(suggestion.toUpperCase());
        },
      ),
    );
  }

//----------------------- FIN DE FUNCIONES DEL INPUTS DATOS DE OTRAS TABLAS-------------------------------

//-----------------------FUNCIONES DEL INPUTS DATOS DE FALLAS--------------------------------

  Widget _buildAnimatedDropdown(String label, List<String> items,
      String? selectedItem, Function(String?) onChanged) {
    TextEditingController controller =
        TextEditingController(text: selectedItem);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TypeAheadField<String>(
        controller: controller,
        builder: (context, fieldController, focusNode) => TextFormField(
          controller: fieldController,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            suffixIcon: Icon(Icons.arrow_drop_down, color: Colors.grey),
          ),
        ),
        suggestionsCallback: (pattern) {
          return items
              .where(
                  (item) => item.toLowerCase().contains(pattern.toLowerCase()))
              .toList();
        },
        itemBuilder: (context, suggestion) {
          return ListTile(
              title: Text(suggestion)); // ✅ Se muestra la Falla + Descripción
        },
        onSelected: (suggestion) {
          // ✅ Se extrae solo la "Falla" antes del guion "-"
          String fallaSeleccionada = suggestion.split(" - ").first;
          controller.text = fallaSeleccionada;
          onChanged(fallaSeleccionada); // ✅ Solo guarda la falla
        },
        transitionBuilder: (context, animation, child) => child,
      ),
    );
  }

// -------------------------fecha------------------------------------------------------

  Widget _buildDOTSemanaAnioField(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    final semanas =
        List.generate(52, (i) => (i + 1).toString().padLeft(2, '0')); // 01–52
    final anios = List.generate(DateTime.now().year - 1999,
        (i) => (2000 + i).toString()); // 2000–actual

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedSemanaDOT,
              items: semanas
                  .map((sem) =>
                      DropdownMenuItem(value: sem, child: Text("SEM $sem")))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedSemanaDOT = value;
                  controller.text = _formatearDOT();
                });
              },
              decoration: InputDecoration(
                labelText: "$label ",
                prefixIcon: Icon(icon, color: Colors.blueGrey[700]),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedAnioDOT,
              items: anios
                  .map((anio) =>
                      DropdownMenuItem(value: anio, child: Text("AÑO $anio")))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedAnioDOT = value;
                  controller.text = _formatearDOT();
                });
              },
              decoration: InputDecoration(
                labelText: "$label ",
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatearDOT() {
    if (_selectedSemanaDOT != null && _selectedAnioDOT != null) {
      final dosDigitosAnio = _selectedAnioDOT!.substring(2, 4);
      return "${_selectedSemanaDOT!}$dosDigitosAnio";
    }
    return "";
  }

////  -----------------------------------------------------------------
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Text(
        title,
        style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color.fromARGB(255, 10, 9, 5)),
      ),
    );
  }
}
//----------------------- FIN DE FUNCIONES DEL INPUTS DATOS DE FALLAS--------------------------------

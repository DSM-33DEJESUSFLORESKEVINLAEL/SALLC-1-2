import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:miapp/db/iniTabla.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../db/db_crud.dart';
import '../../../models/unidades.dart';
import '../../../navigation/app_drawer.dart';

class UnidadesListScreen extends StatefulWidget {
  const UnidadesListScreen({super.key});

  @override
  UnidadesListScreenState createState() => UnidadesListScreenState();
}

class UnidadesListScreenState extends State<UnidadesListScreen> {
  List<Unidad> _unidades = [];
  bool _isLoading = true; // ✅ Agregar bandera de carga

  @override
  void initState() {
    super.initState();
    _loadUnidades();
  }

 
// void _loadUnidades() async {
//   // Supón que recuperas los datos del usuario actual desde SharedPreferences
//   final prefs = await SharedPreferences.getInstance();
//   final userData = prefs.getString("userData");
//   final user = userData != null ? jsonDecode(userData) : {};
//   final empresa = user["EMPRESA"] ?? "";
//   final base = user["BASE"] ?? "";

//   // Filtra por empresa y base
//   List<Map<String, dynamic>> unidadesData = await DBOperations.instance.queryWhere(
//     'unidades',
//     where: 'EMPRESA = ? AND BASE = ?',
//     whereArgs: [empresa, base],
//   );

//   setState(() {
//     _unidades = unidadesData.map((data) => Unidad.fromMap(data)).toList();
//     _isLoading = false;
//   });
// }
void _loadUnidades() async {
  final prefs = await SharedPreferences.getInstance();
  final userData = prefs.getString("userData");
  final user = userData != null ? jsonDecode(userData) : {};
  final empresa = user["EMPRESA"] ?? "";
  final base = user["BASE"] ?? "";

  // 🔍 Consulta
  List<Map<String, dynamic>> unidadesData = await DBOperations.instance.queryWhere(
    'unidades',
    where: 'EMPRESA = ? AND BASE = ?',
    whereArgs: [empresa, base],
  );

  // 📋 Mostrar en consola
  logger.i("📦 Datos obtenidos desde SQLite para UNIDADES:");
  for (var u in unidadesData) {
    logger.i("👉 $u");
  }

  setState(() {
    _unidades = unidadesData.map((data) => Unidad.fromMap(data)).toList();
    _isLoading = false;
  });
}


  void _deleteUnidad(String unidadId) async {
    // await DBOperations.instance.delete('unidades', 'unidad', unidadId);
    _loadUnidades();
  }

  /// 🔹 **Cambiar la pantalla seleccionada**
  void _onItemTapped(int index) {
    setState(() {});
    Navigator.pop(context); // ✅ Cierra el Drawer al seleccionar una opción
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(onSelectItem: _onItemTapped), // Asegurar que el Drawer está definido en Scaffold
      appBar: AppBar(
        title: const Text("Lista de Unidades"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 10),
                    Text("Cargando datos...", style: TextStyle(fontSize: 16)),
                  ],
                ),
              )
            : _unidades.isEmpty
                ? const Center(child: Text("No hay unidades registradas"))
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(), // ✅ Permite desplazamiento
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columnSpacing: 20,
                        headingRowColor: WidgetStateProperty.all<Color>(const Color(0xFFFFCC00)), // ✅ Color de encabezado
                        columns: const [
                          DataColumn(label: Text("Unidad", style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text("Base", style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text("Folio", style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text("Ejes", style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text("Num. Llantas", style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text("Acciones", style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: _unidades.map((unidad) {
                          return DataRow(cells: [
                            DataCell(Text(unidad.unidad)),
                            DataCell(Text(unidad.base)),
                            DataCell(Text(unidad.folio)),
                            DataCell(Text(unidad.ejes?.toString() ?? 'N/A')),
                            DataCell(Text(unidad.numllantas?.toString() ?? 'N/A')),
                            DataCell(
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteUnidad(unidad.unidad),
                                  ),
                                ],
                              ),
                            ),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
      ),
    );
  }
}

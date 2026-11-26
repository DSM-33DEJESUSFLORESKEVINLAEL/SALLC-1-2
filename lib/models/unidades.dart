class Unidad {
  String unidad;
  int empresa;
  String base;
  String folio;
  String? tunidad;
  String? obs;
  String? status;
  int? ejes;
  int? numllantas;

  Unidad({
    required this.unidad,
    required this.empresa,
    required this.base,
    required this.folio,
    this.tunidad,
    this.obs,
    this.status,
    this.ejes,
    this.numllantas,
  });

  /// 🔹 Convierte un `Map` (de la BD) en un objeto `Unidad`
  factory Unidad.fromMap(Map<String, dynamic> map) {
    int empresaConvertida = 0;
    if (map.containsKey('empresa') && map['empresa'] != null) {
      empresaConvertida = int.tryParse(map['empresa'].toString().trim()) ?? 0;
    } else if (map.containsKey('EMPRESA') && map['EMPRESA'] != null) {
      empresaConvertida = int.tryParse(map['EMPRESA'].toString().trim()) ?? 0;
    }

    String unidadConvertida =
        map['unidad']?.toString().trim() ?? map['UNIDAD']?.toString().trim() ?? "Sin definir";

    String baseConvertida =
        map['base']?.toString().trim() ?? map['BASE']?.toString().trim() ?? "Sin base";

    String folioConvertido =
        map['folio']?.toString().trim() ?? map['FOLIO']?.toString().trim() ?? "Sin folio";

    String? tunidadConvertida =
        map['tunidad']?.toString().trim() ?? map['TUNIDAD']?.toString().trim();

    String? obsConvertida = map['obs']?.toString().trim() ?? map['OBS']?.toString().trim();

    String? statusConvertido = map['status']?.toString().trim() ?? map['STATUS']?.toString().trim();

    // int? ejesConvertidos = map['ejes'] is int
    //     ? map['ejes']
    //     : int.tryParse(map['ejes']?.toString().trim() ?? '');
    int? ejesConvertidos;
if (map.containsKey('ejes') && map['ejes'] != null) {
  ejesConvertidos = int.tryParse(map['ejes'].toString().trim());
} else if (map.containsKey('EJES') && map['EJES'] != null) {
  ejesConvertidos = int.tryParse(map['EJES'].toString().trim());
}


    // int? numLlantasConvertidas = map['num_llantas'] is int
    //     ? map['num_llantas']
    //     : int.tryParse(map['num_llantas']?.toString().trim() ?? '');
    int? numLlantasConvertidas;
if (map.containsKey('num_llantas') && map['num_llantas'] != null) {
  numLlantasConvertidas = int.tryParse(map['num_llantas'].toString().trim());
} else if (map.containsKey('NUM_LLANTAS') && map['NUM_LLANTAS'] != null) {
  numLlantasConvertidas = int.tryParse(map['NUM_LLANTAS'].toString().trim());
}


    return Unidad(
      unidad: unidadConvertida,
      empresa: empresaConvertida,
      base: baseConvertida,
      folio: folioConvertido,
      tunidad: tunidadConvertida,
      obs: obsConvertida,
      status: statusConvertido,
      ejes: ejesConvertidos,
      numllantas: numLlantasConvertidas,
    );
  }

  /// 🔹 Convierte un objeto `Unidad` a un `Map` para almacenar en la BD
  Map<String, dynamic> toMap() {
    return {
      "unidad": unidad,
      "empresa": empresa,
      "base": base,
      "folio": folio,
      "tunidad": tunidad,
      "obs": obs,
      "status": status,
      "ejes": ejes,
      "num_llantas": numllantas,
    };
  }

  /// 🔹 Convierte un JSON en un objeto `Unidad`
  factory Unidad.fromJson(Map<String, dynamic> json) {
    int empresaConvertida = json['EMPRESA'] is int
        ? json['EMPRESA']
        : int.tryParse(json['EMPRESA']?.toString().trim() ?? '0') ?? 0;

    String unidadConvertida = json['UNIDAD']?.toString().trim() ?? "Sin definir";

    String baseConvertida = json['BASE']?.toString().trim() ?? "Sin base";

    String folioConvertido = json['FOLIO']?.toString().trim() ?? "Sin folio";

    String? tunidadConvertida = json['TUNIDAD']?.toString().trim();

    String? obsConvertida = json['OBS']?.toString().trim();

    String? statusConvertido = json['STATUS']?.toString().trim();

    int? ejesConvertidos = json['EJES'] is int
        ? json['EJES']
        : int.tryParse(json['EJES']?.toString().trim() ?? '');

    int? numLlantasConvertidas = json['NUM_LLANTAS'] is int
        ? json['NUM_LLANTAS']
        : int.tryParse(json['NUM_LLANTAS']?.toString().trim() ?? '');

    return Unidad(
      unidad: unidadConvertida,
      empresa: empresaConvertida,
      base: baseConvertida,
      folio: folioConvertido,
      tunidad: tunidadConvertida,
      obs: obsConvertida,
      status: statusConvertido,
      ejes: ejesConvertidos,
      numllantas: numLlantasConvertidas,
    );
  }
}

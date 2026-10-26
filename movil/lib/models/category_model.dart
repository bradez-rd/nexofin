class CategoryModel {
  final String id;
  final String nombre;
  final String tipo; // 'ingreso', 'gasto', 'ambos'
  final String? icono;
  final String? color;
  final bool esSistema;

  CategoryModel({
    required this.id,
    required this.nombre,
    required this.tipo,
    this.icono,
    this.color,
    required this.esSistema,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      tipo: json['tipo']?.toString() ?? 'gasto',
      icono: json['icono']?.toString(),
      color: json['color']?.toString(),
      esSistema: json['es_sistema'] == true || json['es_sistema'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'tipo': tipo,
      'icono': icono,
      'color': color,
      'es_sistema': esSistema,
    };
  }
}

class UserModel {
  final String id;
  final String nombre;
  final String email;
  final String monedaPredeterminada;
  final String zonaHoraria;
  final String? fotoUrl;

  UserModel({
    required this.id,
    required this.nombre,
    required this.email,
    required this.monedaPredeterminada,
    required this.zonaHoraria,
    this.fotoUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      monedaPredeterminada: json['moneda_predeterminada']?.toString() ?? 'DOP',
      zonaHoraria: json['zona_horaria']?.toString() ?? 'America/Santo_Domingo',
      fotoUrl: json['foto_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'email': email,
      'moneda_predeterminada': monedaPredeterminada,
      'zona_horaria': zonaHoraria,
      'foto_url': fotoUrl,
    };
  }
}

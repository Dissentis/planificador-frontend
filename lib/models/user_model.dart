// lib/models/user_model.dart

class UserModel {
  String name;
  String lastName;
  String school;
  String province;
  String autonomousCommunity;

  UserModel({
    this.name = '',
    this.lastName = '',
    this.school = '',
    this.province = '',
    this.autonomousCommunity = '',
  });

  // Crea un objeto UserModel desde un Mapa (leído de un JSON)
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      name: json['name'] ?? '',
      lastName: json['lastName'] ?? '',
      school: json['school'] ?? '',
      province: json['province'] ?? '',
      autonomousCommunity: json['autonomousCommunity'] ?? '',
    );
  }

  // Convierte un objeto UserModel a un Mapa (para luego convertir a JSON)
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'lastName': lastName,
      'school': school,
      'province': province,
      'autonomousCommunity': autonomousCommunity,
    };
  }
}
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../models/position.dart';

class ApiService {
  static const String baseUrl = 'http://10.0.2.2:5000';

  static Future<List<User>> fetchUsers() async {
    final response = await http.get(Uri.parse('$baseUrl/users'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((item) => User.fromJson(item)).toList();
    } else {
      throw Exception('Kullanıcılar yüklenemedi: ${response.statusCode}');
    }
  }

  static Future<List<Position>> fetchPositions() async {
    final response = await http.get(
      Uri.parse('$baseUrl/locations'),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((item) => Position.fromJson(item)).toList();
    } else {
      throw Exception('Pozisyonlar yüklenemedi: ${response.statusCode}');
    }
  }

  // yeni kullanıcı ekleme
  static Future<void> addUser(String username) async {
    final response = await http.post(
      Uri.parse('$baseUrl/add_user'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'username': username}),
    );

    if (response.statusCode == 201) {
      // Başarılı
      print('Kullanıcı başarıyla eklendi');
    } else {
      // Başarısız
      print('Kullanıcı eklenemedi: ${response.statusCode}, ${response.body}');
      throw Exception('Kullanıcı eklenemedi: ${response.statusCode}');
    }
  }

  // Kullanıcı silme
  static Future<void> deleteUser(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/users/$id'));
    if (response.statusCode != 204) {
      throw Exception('Kullanıcı silinemedi: ${response.statusCode}');
    }
  }
}

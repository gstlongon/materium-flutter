import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final String baseUrl = 'https://materium-api.vercel.app/api';

  /// Retorna um Map com os dados do usuário se o login for bem-sucedido,
  /// ou null se falhar.
  Future<Map<String, dynamic>?> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/auth/login');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final token = data['token'];
      final user = data['user'];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);

      return user; // Retorna o usuário
    } else {
      return null; // Login falhou
    }
  }

  Future<bool> register(
    String name,
    String email,
    String password,
    String role,
  ) async {
    final url = Uri.parse('$baseUrl/users/register');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'role': role,
      }),
    );

    print('Status code: ${response.statusCode}');
    print('Response body: ${response.body}');

    return response.statusCode == 201;
  }
}

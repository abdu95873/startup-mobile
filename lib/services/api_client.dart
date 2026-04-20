import "dart:convert";

import "package:http/http.dart" as http;

class ApiClient {
  ApiClient(this.baseUrl, {this.token});

  final String baseUrl;
  final String? token;

  Map<String, String> get _headers {
    final h = <String, String>{"Content-Type": "application/json"};
    if (token != null && token!.isNotEmpty) {
      h["Authorization"] = "Bearer $token";
    }
    return h;
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse("$baseUrl/api/auth/login"),
      headers: _headers,
      body: jsonEncode({"email": email, "password": password}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception("Login failed (${res.statusCode})");
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse("$baseUrl/api/auth/register"),
      headers: _headers,
      body: jsonEncode({
        "name": name,
        "email": email,
        "password": password,
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception("Register failed (${res.statusCode})");
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMe() async {
    final res = await http.get(Uri.parse("$baseUrl/api/auth/me"), headers: _headers);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception("Could not fetch profile (${res.statusCode})");
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getProducts() async {
    final res = await http.get(Uri.parse("$baseUrl/api/products"), headers: _headers);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception("Failed to load products (${res.statusCode})");
    }
    final decoded = jsonDecode(res.body);
    final raw = decoded is List
        ? decoded
        : (decoded["data"] as List<dynamic>? ?? <dynamic>[]);
    return raw.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getQrByCode(String code) async {
    final res = await http.get(Uri.parse("$baseUrl/api/qr/code/$code"), headers: _headers);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception("QR not found or server error (${res.statusCode})");
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}

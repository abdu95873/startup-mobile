import "package:shared_preferences/shared_preferences.dart";

import "../core/constants.dart";
import "../models/auth_session.dart";

class SessionStore {
  static Future<AuthSession?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(tokenKey);
    final email = prefs.getString(emailKey) ?? "";
    if (token == null || token.isEmpty) return null;
    return AuthSession(token: token, email: email);
  }

  static Future<void> save(AuthSession s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(tokenKey, s.token);
    await prefs.setString(emailKey, s.email);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(tokenKey);
    await prefs.remove(emailKey);
  }
}

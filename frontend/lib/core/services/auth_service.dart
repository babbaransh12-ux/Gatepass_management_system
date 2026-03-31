import 'package:shared_preferences/shared_preferences.dart';

class AuthService {

  /// Save login information
  static Future<void> saveLogin(String role, String token, String uid) async {

    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool("logged_in", true);
    await prefs.setString("role", role);
    await prefs.setString("jwt_token", token);
    await prefs.setString("uid", uid);

  }

  /// Get saved user ID
  static Future<String?> getUid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("uid");
  }

  /// Get saved role
  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    bool? loggedIn = prefs.getBool("logged_in");

    if (loggedIn == true) {
      return prefs.getString("role");
    }
    return null;
  }

  /// Get saved JWT Token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("jwt_token");
  }

  /// Logout user
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

}
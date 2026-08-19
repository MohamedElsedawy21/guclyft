import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = "http://10.0.2.2:8000"; // Android emulator

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  static Future<Map<String, String>> authHeaders() async {
    final token = await getToken();
    return {
      "Content-Type": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    };
  }

  static Future<http.Response> post(String path, Map<String, dynamic> body, {bool auth = false}) async {
    final headers = auth ? await authHeaders() : {"Content-Type": "application/json"};
    return http.post(Uri.parse("$baseUrl$path"), headers: headers, body: jsonEncode(body));
  }

  static Future<http.Response> get(String path, {bool auth = false}) async {
    final headers = auth ? await authHeaders() : {"Content-Type": "application/json"};
    return http.get(Uri.parse("$baseUrl$path"), headers: headers);
  }

    static Future<http.Response> postMultipart(
    String path, {
    required Map<String, String> fields,
    required String filePath,
    required String fileFieldName,
  }) async {
    final token = await getToken();
    final request = http.MultipartRequest("POST", Uri.parse("$baseUrl$path"));
    if (token != null) {
      request.headers["Authorization"] = "Bearer $token";
    }
    request.fields.addAll(fields);
    request.files.add(await http.MultipartFile.fromPath(fileFieldName, filePath));

    final streamedResponse = await request.send();
    return http.Response.fromStream(streamedResponse);
  }
  
    static Future<http.Response> put(String path, Map<String, dynamic> body, {bool auth = false}) async {
    final headers = auth ? await authHeaders() : {"Content-Type": "application/json"};
    return http.put(Uri.parse("$baseUrl$path"), headers: headers, body: jsonEncode(body));
  }
}
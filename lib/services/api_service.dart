// api_service.dart (revisi)
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Root API (folder /api)
  static const String apiRoot = 'http://localhost/api';
  // static const String apiRoot = '10.23.83.199';
  // Legacy single-file base (profiles.php) - keep if some endpoints use query ?type=
  static const String baseProfiles = '$apiRoot/profiles.php';

  static const Map<String, String> headers = {
    'Content-Type': 'application/json',
  };

  // ---------------- AUTH ----------------
  Future<Map<String, dynamic>> register(String fullname, String username, String password) async {
    final url = Uri.parse('$baseProfiles?type=register');
    final response = await http.post(url, headers: headers, body: jsonEncode({
      'fullname': fullname,
      'username': username,
      'password': password,
    })).timeout(const Duration(seconds: 10));
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    final url = Uri.parse('$baseProfiles?type=login');
    final response = await http.post(url, headers: headers, body: jsonEncode({
      'username': username,
      'password': password,
    })).timeout(const Duration(seconds: 10));

    final data = jsonDecode(response.body);
    if (data['success'] == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user', jsonEncode(data['user']));
    }
    return data;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user');
  }

  Future<Map<String, dynamic>?> getLoggedInUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString('user');
    if (userData != null) return jsonDecode(userData);
    return null;
  }

  // ---------------- PROFILES ----------------
  Future<List<dynamic>> fetchProfiles() async {
    try {
      final uri = Uri.parse('$baseProfiles?type=profile');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        if (j is Map && j['success'] == true && j['data'] != null) return (j['data'] as List);
        if (j is List) return j;
      } else {
        debugPrint('fetchProfiles: status ${res.statusCode} body: ${res.body}');
      }
    } catch (e) {
      debugPrint('fetchProfiles error: $e');
    }
    return [];
  }

  Future<bool> createProfile(Map<String, dynamic> p) async {
    try {
      final uri = Uri.parse('$baseProfiles?type=profile');
      final res = await http.post(uri, headers: headers, body: jsonEncode(p)).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        return j['success'] == true || j['id'] != null;
      } else {
        debugPrint('createProfile status ${res.statusCode} body: ${res.body}');
      }
    } catch (e) {
      debugPrint('createProfile error: $e');
    }
    return false;
  }

  Future<bool> updateProfile(Map<String, dynamic> p) async {
    try {
      final uri = Uri.parse('$baseProfiles?type=profile');
      final res = await http.put(uri, headers: headers, body: jsonEncode(p)).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        return j['success'] == true;
      } else {
        debugPrint('updateProfile status ${res.statusCode} body: ${res.body}');
      }
    } catch (e) {
      debugPrint('updateProfile error: $e');
    }
    return false;
  }

  Future<bool> deleteProfile(int id) async {
    try {
      final uri = Uri.parse('$baseProfiles?type=profile&id=$id');
      final res = await http.delete(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        return j['success'] == true;
      } else {
        debugPrint('deleteProfile status ${res.statusCode} body: ${res.body}');
      }
    } catch (e) {
      debugPrint('deleteProfile error: $e');
    }
    return false;
  }

  // ---------------- HISTORY ----------------
  Future<List<dynamic>> fetchHistory() async {
    try {
      final uri = Uri.parse('$baseProfiles?type=history');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        if (j is Map && j['success'] == true && j['data'] != null) return (j['data'] as List);
        if (j is List) return j;
      } else {
        debugPrint('fetchHistory status ${res.statusCode} body: ${res.body}');
      }
    } catch (e) {
      debugPrint('fetchHistory error: $e');
    }
    return [];
  }

  Future<bool> addHistory(Map<String, dynamic> history) async {
    try {
      final uri = Uri.parse('$baseProfiles?type=history');
      final res = await http.post(uri, headers: headers, body: jsonEncode(history)).timeout(const Duration(seconds: 10));
      debugPrint("addHistory Response Code: ${res.statusCode}");
      debugPrint("addHistory Response Body: ${res.body}");
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        return j['success'] == true;
      }
    } catch (e) {
      debugPrint('addHistory error: $e');
    }
    return false;
  }

  Future<bool> deleteHistory(int id) async {
    try {
      final uri = Uri.parse('$baseProfiles?type=history&id=$id');
      final res = await http.delete(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        return j['success'] == true;
      }
    } catch (e) {
      debugPrint('deleteHistory error: $e');
    }
    return false;
  }

  // ---------------- SENSOR ----------------
  Future<List<dynamic>> fetchSensor({int limit = 20}) async {
    try {
      final uri = Uri.parse('$baseProfiles?type=sensor&limit=$limit');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        if (j is Map && j['success'] == true && j['data'] != null) return (j['data'] as List);
        if (j is List) return j;
      } else {
        debugPrint('fetchSensor status ${res.statusCode} body: ${res.body}');
      }
    } catch (e) {
      debugPrint('fetchSensor error: $e');
    }
    return [];
  }

  // ---------------- FERMENTATION CONTROL (preferred) ----------------
  // Use set_fermentation.php as single source of truth for on/off.
  Future<bool> setFermentationStatus(int profileId, bool on, {int? userId}) async {
    try {
      final uri = Uri.parse('$apiRoot/set_fermentation.php');
      final body = {
        "profile_id": profileId,
        "command": on ? "start" : "stop",
        "user_id": userId ?? 0
      };
      final res = await http.post(uri, headers: headers, body: jsonEncode(body)).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        return j['success'] == true;
      } else {
        debugPrint('setFermentationStatus status ${res.statusCode} body: ${res.body}');
      }
    } catch (e) {
      debugPrint('setFermentationStatus error: $e');
    }
    return false;
  }

  // Legacy toggleFermentation (keamanan backward-compat)
  Future<bool> toggleFermentation(int profileId, bool on) async {
    try {
      final uri = Uri.parse('$baseProfiles?type=fermentation');
      final res = await http.post(uri, headers: headers, body: jsonEncode({'profile_id': profileId, 'status': on ? 1 : 0})).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        return j['success'] == true;
      } else {
        debugPrint('toggleFermentation status ${res.statusCode} body: ${res.body}');
      }
    } catch (e) {
      debugPrint('toggleFermentation error: $e');
    }
    return false;
  }

  // ---------------- SEND MQTT TO BACKEND (via PHP -> Node-RED) ----------------
  Future<bool> sendMqtt(String topic, Map<String, dynamic> payload) async {
    final url = Uri.parse('$apiRoot/mqtt_publish.php');
    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({
          "topic": topic,
          "payload": payload,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('sendMqtt status ${response.statusCode} body: ${response.body}');
        return false;
      }

      final data = jsonDecode(response.body);
      return data["success"] == true;
    } catch (e) {
      debugPrint("sendMqtt error: $e");
      return false;
    }
  }

  // ---------------- GET / SET FERMENTATION STATUS (helper) ----------------
  Future<Map<String, dynamic>?> getFermentationStatus({int? profileId}) async {
    try {
      final uri = Uri.parse('$apiRoot/get_fermentation_status.php${profileId != null ? '?profile_id=$profileId' : ''}');
      final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        return j;
      } else {
        debugPrint('getFermentationStatus status ${res.statusCode} body: ${res.body}');
      }
    } catch (e) {
      debugPrint('getFermentationStatus error: $e');
    }
    return null;
  }

  // START 
  Future<bool> startFermentation({
  required int profileId,
  required String profileName,
  required int durationMinutes,
  required double targetTempMin,
  required double targetTempMax,
  required double targetPh,
}) async {
  final url = Uri.parse('$apiRoot/mqtt_publish.php');
  final payload = {
    "command": "start",
    "profile_id": profileId,
    "profile_name": profileName,
    "duration_minutes": durationMinutes,
    "temp_min": targetTempMin,
    "temp_max": targetTempMax,
    "target_ph": targetPh,
  };
  try {
    final res = await http.post(url, headers: headers, body: jsonEncode({
      "topic": "ferment/control",
      "payload": payload,
    })).timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) {
      final j = jsonDecode(res.body);
      return j['success'] == true;
    }
  } catch (e) {
    debugPrint("startFermentation error: $e");
  }
  return false;
}

// STOP
Future<bool> stopFermentation({int? profileId}) async {
  final url = Uri.parse('$apiRoot/mqtt_publish.php');
  final payload = {"command": "stop", "profile_id": profileId ?? 0};
  try {
    final res = await http.post(
  url,
  headers: headers,
  body: jsonEncode({
    "topic": "ferment/control",
    "payload": payload,
  }),
  ).timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) {
      final j = jsonDecode(res.body);
      return j['success'] == true;
    }
  } catch (e) {
    debugPrint("stopFermentation error: $e");
  }
  return false;
}
}

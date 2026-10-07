import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  final int status; final String message;
  ApiException(this.status, this.message);
  @override String toString() => message;
}

class ApiService {
  static const String baseUrl = 'https://radinskateomd.ir/api/v1';
  final SharedPreferences prefs;
  ApiService(this.prefs);

  String? get token => prefs.getString('token');
  int? get membershipId => prefs.getInt('membership_id');
  bool get loggedIn => token != null && token!.isNotEmpty;

  Future<dynamic> request(String method, String path, {Map<String,dynamic>? body, bool auth=true, bool membership=false}) async {
    final headers = <String,String>{'Accept':'application/json','Content-Type':'application/json','Accept-Language':'fa'};
    if (auth && token != null) headers['Authorization'] = 'Bearer $token';
    if (membership && membershipId != null) headers['X-Membership-ID'] = '$membershipId';
    final uri = Uri.parse('$baseUrl$path');
    late http.Response res;
    if (method == 'POST') res = await http.post(uri, headers: headers, body: jsonEncode(body ?? {}));
    else if (method == 'PUT') res = await http.put(uri, headers: headers, body: jsonEncode(body ?? {}));
    else res = await http.get(uri, headers: headers);
    dynamic data;
    try { data = res.body.isEmpty ? {} : jsonDecode(res.body); } catch (_) { data = {}; }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final msg = data is Map && data['message'] != null ? '${data['message']}' : 'خطا در ارتباط با سرور (${res.statusCode})';
      if (res.statusCode == 401) await logout();
      throw ApiException(res.statusCode, msg);
    }
    return data;
  }

  Future<void> requestOtp(String phone) async => await request('POST','/auth/request-otp',body:{'phone':phone},auth:false);
  Future<Map<String,dynamic>> verifyOtp(String phone,String code) async {
    final d = Map<String,dynamic>.from(await request('POST','/auth/verify-otp',body:{'phone':phone,'code':code},auth:false));
    await prefs.setString('token', '${d['token']}');
    await prefs.setString('user_name', '${(d['user'] as Map)['full_name'] ?? ''}');
    final ms = (d['memberships'] as List? ?? []);
    if (ms.isNotEmpty) await prefs.setInt('membership_id', (ms.first['id'] as num).toInt());
    return d;
  }
  Future<Map<String,dynamic>> me() async => Map<String,dynamic>.from(await request('GET','/me'));
  Future<Map<String,dynamic>> dashboard() async => Map<String,dynamic>.from(await request('GET','/dashboard',membership:true));
  Future<Map<String,dynamic>> clubSummary() async => Map<String,dynamic>.from(await request('GET','/club/summary',membership:true));
  Future<List<dynamic>> classes() async => List<dynamic>.from(await request('GET','/club/classes',membership:true));
  Future<dynamic> attendance() async => await request('GET','/club/attendance',membership:true);
  Future<dynamic> announcements() async => await request('GET','/club/announcements',membership:true);
  Future<void> selectMembership(int id) async => await prefs.setInt('membership_id', id);
  Future<void> logout() async { await prefs.remove('token'); await prefs.remove('membership_id'); }
}

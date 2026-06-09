import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../utils/constants.dart';

class ApiService {
  static const String baseUrl = AppConstants.baseUrl;

  // ─── Token helpers ───────────────────────────────────────────
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.tokenKey);
  }

  Future<void> saveToken(String token, String refresh) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.tokenKey, token);
    await prefs.setString(AppConstants.refreshTokenKey, refresh);
  }

  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
    await prefs.remove(AppConstants.refreshTokenKey);
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ─── Auth ─────────────────────────────────────────────────────

  /// Step 1: Send OTP to phone number
  Future<Map<String, dynamic>> sendOtp(String phone) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/send-otp/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone}),
    );
    return _handleResponse(response);
  }

  /// Step 2: Verify OTP — returns tokens + user on success
  Future<Map<String, dynamic>> verifyOtp(String phone, String otp) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/verify-otp/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'otp': otp}),
    );
    return _handleResponse(response);
  }

  /// Logout — blacklists the refresh token
  Future<void> logout(String refreshToken) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/auth/logout/'),
        headers: await _authHeaders(),
        body: jsonEncode({'refresh': refreshToken}),
      );
    } catch (_) {}
    await clearTokens();
  }

  /// Refresh access token using refresh token
  Future<Map<String, dynamic>> refreshToken(String refresh) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/token/refresh/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh': refresh}),
    );
    return _handleResponse(response);
  }

  // ─── Profile ──────────────────────────────────────────────────

  Future<Map<String, dynamic>> getProfile() async {
    final response = await http.get(
      Uri.parse('$baseUrl/profile/'),
      headers: await _authHeaders(),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/profile/'),
      headers: await _authHeaders(),
      body: jsonEncode(data),
    );
    return _handleResponse(response);
  }

  // ─── Business ─────────────────────────────────────────────────

  Future<Map<String, dynamic>> getBusiness() async {
    final response = await http.get(
      Uri.parse('$baseUrl/business/'),
      headers: await _authHeaders(),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> createBusiness(
      Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/business/create/'),
      headers: await _authHeaders(),
      body: jsonEncode(data),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> updateBusiness(
      Map<String, dynamic> data) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/business/'),
      headers: await _authHeaders(),
      body: jsonEncode(data),
    );
    return _handleResponse(response);
  }

  // ─── Dashboard ────────────────────────────────────────────────

  Future<Map<String, dynamic>> getDashboardStats() async {
    final response = await http.get(
      Uri.parse('$baseUrl/dashboard/'),
      headers: await _authHeaders(),
    );
    return _handleResponse(response);
  }

  // ─── Customers ────────────────────────────────────────────────

  Future<List<Customer>> getCustomers({String? balanceFilter}) async {
    var url = '$baseUrl/customers/';
    if (balanceFilter != null) {
      url += '?balance_filter=$balanceFilter';
    }
    final response = await http.get(
      Uri.parse(url),
      headers: await _authHeaders(),
    );
    final data = _handleResponse(response);
    final list = data['results'] ?? data;
    return (list as List).map((e) => Customer.fromJson(e)).toList();
  }

  Future<Map<String, dynamic>> getCustomerDetail(String id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/customers/$id/'),
      headers: await _authHeaders(),
    );
    return _handleResponse(response);
  }

  Future<Customer> addCustomer(Customer customer) async {
    final response = await http.post(
      Uri.parse('$baseUrl/customers/'),
      headers: await _authHeaders(),
      body: jsonEncode(customer.toJson()),
    );
    return Customer.fromJson(_handleResponse(response));
  }

  Future<Customer> updateCustomer(Customer customer) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/customers/${customer.id}/'),
      headers: await _authHeaders(),
      body: jsonEncode(customer.toJson()),
    );
    return Customer.fromJson(_handleResponse(response));
  }

  Future<void> deleteCustomer(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/customers/$id/'),
      headers: await _authHeaders(),
    );
    _handleResponse(response);
  }

  Future<List<AppTransaction>> getCustomerTransactions(String customerId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/customers/$customerId/transactions/'),
      headers: await _authHeaders(),
    );
    final data = _handleResponse(response);
    final list = data['results'] ?? data;
    return (list as List).map((e) => AppTransaction.fromJson(e)).toList();
  }

  Future<Map<String, dynamic>> sendReminder(
      String customerId, String message) async {
    final response = await http.post(
      Uri.parse('$baseUrl/customers/$customerId/remind/'),
      headers: await _authHeaders(),
      body: jsonEncode({'message': message}),
    );
    return _handleResponse(response);
  }

  // ─── Transactions ─────────────────────────────────────────────

  Future<List<AppTransaction>> getTransactions({
    String? customerId,
    String? startDate,
    String? endDate,
    String? type,
    String? paymentMode,
  }) async {
    final params = <String, String>{};
    if (customerId != null) params['customer'] = customerId;
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null) params['end_date'] = endDate;
    if (type != null) params['transaction_type'] = type;
    if (paymentMode != null) params['payment_mode'] = paymentMode;

    final uri = Uri.parse('$baseUrl/transactions/').replace(
      queryParameters: params.isNotEmpty ? params : null,
    );
    final response = await http.get(uri, headers: await _authHeaders());
    final data = _handleResponse(response);
    final list = data['results'] ?? data;
    return (list as List).map((e) => AppTransaction.fromJson(e)).toList();
  }

  Future<AppTransaction> addTransaction(AppTransaction transaction) async {
    final response = await http.post(
      Uri.parse('$baseUrl/transactions/'),
      headers: await _authHeaders(),
      body: jsonEncode(transaction.toJson()),
    );
    return AppTransaction.fromJson(_handleResponse(response));
  }

  Future<void> deleteTransaction(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/transactions/$id/'),
      headers: await _authHeaders(),
    );
    _handleResponse(response);
  }

  // ─── Reports ──────────────────────────────────────────────────

  Future<Map<String, dynamic>> getMonthlyReport(int year, int month) async {
    final response = await http.get(
      Uri.parse('$baseUrl/reports/?type=monthly'),
      headers: await _authHeaders(),
    );
    return _handleResponse(response);
  }

  // ─── Reminders ────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getReminders() async {
    final response = await http.get(
      Uri.parse('$baseUrl/reminders/'),
      headers: await _authHeaders(),
    );
    final data = _handleResponse(response);
    final list = data['results'] ?? data;
    return (list as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createReminder(
      Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/reminders/'),
      headers: await _authHeaders(),
      body: jsonEncode(data),
    );
    return _handleResponse(response);
  }

  // ─── Response handler ─────────────────────────────────────────
  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      final decoded = jsonDecode(response.body);
      if (decoded is List) return {'results': decoded};
      return decoded as Map<String, dynamic>;
    } else {
      String message = 'Request failed (${response.statusCode})';
      try {
        final body = jsonDecode(response.body);
        if (body is Map) {
          message = body['detail'] ??
              body['message'] ??
              body['error'] ??
              body.values.first?.toString() ??
              message;
        }
      } catch (_) {}
      throw Exception(message);
    }
  }
}
import 'dart:convert';

import 'timed_http.dart';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

/// Small authenticated client for the Oyudent admin API.
/// Screens keep form state; all network details and response checks live here.
class OyudentApi {
  OyudentApi(this.token);

  static const baseUrl = 'https://api.oyudent.com/admin/api/v1';
  final String token;

  Map<String, String> get _headers => {
    if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  Future<Map<String, dynamic>> get(
    String path, {
    String stage = 'Оюудентийн мэдээллийг ачаалж байна',
    Duration limit = const Duration(seconds: 30),
  }) async {
    final response = await timedHttp(
      stage,
      limit,
      (client) => client.get(Uri.parse('$baseUrl$path'), headers: _headers),
    );
    return _checked(response);
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> payload,
  ) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl$path'),
          headers: _headers,
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 45));
    return _checked(response);
  }

  Future<Map<String, dynamic>> orderDetails(String id) async {
    final response = await get('/order/detail/${Uri.encodeComponent(id)}');
    final data = response['data'];
    if (data is! Map<String, dynamic> || data['items'] is! List) {
      throw const FormatException('Захиалгын мэдээлэл авах боломжгүй байна.');
    }
    return data;
  }

  Future<void> delete(String path) async {
    _checked(
      await http
          .delete(Uri.parse('$baseUrl$path'), headers: _headers)
          .timeout(const Duration(seconds: 30)),
    );
  }

  Future<Map<String, dynamic>> uploadImage(
    String path, {
    required Map<String, String> fields,
    required PlatformFile image,
    String fieldName = 'image',
  }) async {
    if (token.isEmpty) throw Exception('Зураг оруулахын өмнө нэвтэрнэ үү.');
    if (image.bytes == null)
      throw Exception('${image.name} файлыг уншиж чадсангүй.');
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'))
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Accept'] = 'application/json'
      ..fields.addAll(fields)
      ..files.add(
        http.MultipartFile.fromBytes(
          fieldName,
          image.bytes!,
          filename: image.name,
        ),
      );
    final streamed = await request.send().timeout(const Duration(seconds: 45));
    return _checked(
      http.Response(await streamed.stream.bytesToString(), streamed.statusCode),
    );
  }

  Map<String, dynamic> _checked(http.Response response) {
    Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(response.body);
      body = decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : {'data': decoded};
    } catch (_) {
      body = {'message': response.body};
    }
    final status = response.statusCode;
    if (status < 200 ||
        status >= 300 ||
        (body['status'] != null && body['status'] != 'success')) {
      final errors = body['errors'];
      final message = errors is List && errors.isNotEmpty
          ? errors.first.toString()
          : (body['message'] ??
                    body['error'] ??
                    'Системийн хүсэлт амжилтгүй ($status)')
                .toString();
      throw Exception(message);
    }
    return body;
  }
}

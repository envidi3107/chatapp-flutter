import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/app_constants.dart';
import '../models/token_pair_model.dart';
import 'token_storage_service.dart';

class ApiClient {
  ApiClient({
    required TokenStorageService tokenStorage,
    http.Client? httpClient,
  })  : _tokenStorage = tokenStorage,
        _httpClient = httpClient ?? http.Client();

  final TokenStorageService _tokenStorage;
  final http.Client _httpClient;

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    return Uri.parse('${AppConstants.baseUrl}$path').replace(
      queryParameters: query?.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
    );
  }

  Future<http.Response> get(
    String path, {
    Map<String, dynamic>? query,
    bool authRequired = true,
  }) async {
    return _sendWithRefresh(
      () async => _httpClient.get(
        _uri(path, query),
        headers: await _buildHeaders(authRequired: authRequired),
      ),
      authRequired: authRequired,
    );
  }

  Future<http.Response> postJson(
    String path,
    Map<String, dynamic> body, {
    Map<String, dynamic>? query,
    bool authRequired = true,
  }) async {
    return _sendWithRefresh(
      () async => _httpClient.post(
        _uri(path, query),
        headers: await _buildHeaders(authRequired: authRequired),
        body: jsonEncode(body),
      ),
      authRequired: authRequired,
    );
  }

  Future<http.Response> patchJson(
    String path,
    Map<String, dynamic> body, {
    Map<String, dynamic>? query,
    bool authRequired = true,
  }) async {
    return _sendWithRefresh(
      () async => _httpClient.patch(
        _uri(path, query),
        headers: await _buildHeaders(authRequired: authRequired),
        body: jsonEncode(body),
      ),
      authRequired: authRequired,
    );
  }

  Future<http.Response> delete(
    String path, {
    Map<String, dynamic>? query,
    bool authRequired = true,
  }) async {
    return _sendWithRefresh(
      () async => _httpClient.delete(
        _uri(path, query),
        headers: await _buildHeaders(authRequired: authRequired),
      ),
      authRequired: authRequired,
    );
  }

  Future<http.StreamedResponse> postMultipart(
    String path, {
    required Map<String, String> fields,
    required Future<List<http.MultipartFile>> Function() buildFiles,
    Map<String, dynamic>? query,
    bool authRequired = true,
  }) async {
    final request = http.MultipartRequest('POST', _uri(path, query));
    request.headers.addAll(
      await _buildHeaders(
        authRequired: authRequired,
        includeJsonContentType: false,
      ),
    );
    request.fields.addAll(fields);
    request.files.addAll(await buildFiles());
    var streamed = await request.send();

    if (authRequired && streamed.statusCode == 401 && await _refreshToken()) {
      final retry = http.MultipartRequest('POST', _uri(path, query));
      retry.headers.addAll(
        await _buildHeaders(
          authRequired: authRequired,
          includeJsonContentType: false,
        ),
      );
      retry.fields.addAll(fields);
      retry.files.addAll(await buildFiles());
      streamed = await retry.send();
    }

    return streamed;
  }

  Future<http.StreamedResponse> putMultipart(
    String path, {
    required Map<String, String> fields,
    required Future<List<http.MultipartFile>> Function() buildFiles,
    Map<String, dynamic>? query,
    bool authRequired = true,
  }) async {
    final request = http.MultipartRequest('PUT', _uri(path, query));
    request.headers.addAll(
      await _buildHeaders(
        authRequired: authRequired,
        includeJsonContentType: false,
      ),
    );
    request.fields.addAll(fields);
    request.files.addAll(await buildFiles());
    var streamed = await request.send();

    if (authRequired && streamed.statusCode == 401 && await _refreshToken()) {
      final retry = http.MultipartRequest('PUT', _uri(path, query));
      retry.headers.addAll(
        await _buildHeaders(
          authRequired: authRequired,
          includeJsonContentType: false,
        ),
      );
      retry.fields.addAll(fields);
      retry.files.addAll(await buildFiles());
      streamed = await retry.send();
    }

    return streamed;
  }

  Future<http.Response> _sendWithRefresh(
    Future<http.Response> Function() execute, {
    required bool authRequired,
  }) async {
    var response = await execute();

    if (authRequired && response.statusCode == 401 && await _refreshToken()) {
      response = await execute();
    }

    return response;
  }

  Future<Map<String, String>> _buildHeaders({
    required bool authRequired,
    bool includeJsonContentType = true,
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};

    if (includeJsonContentType) {
      headers['Content-Type'] = 'application/json';
    }

    if (authRequired) {
      final access = await _tokenStorage.getAccessToken();
      if (access != null && access.isNotEmpty) {
        headers['Authorization'] = 'Bearer $access';
      }
    }

    return headers;
  }

  Future<bool> _refreshToken() async {
    final refreshToken = await _tokenStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    final response = await _httpClient.post(
      _uri('/api/v1/users/token/refresh/'),
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'refresh': refreshToken}),
    );

    if (response.statusCode != 200) {
      await _tokenStorage.clear();
      return false;
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final access = (body['access'] ?? '').toString();
    if (access.isEmpty) {
      return false;
    }

    final currentRefresh = await _tokenStorage.getRefreshToken() ?? refreshToken;
    await _tokenStorage.saveTokens(
      TokenPairModel(access: access, refresh: currentRefresh),
    );
    return true;
  }
}

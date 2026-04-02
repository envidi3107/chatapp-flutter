import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../models/message_receive_model.dart';
import '../models/message_summary_model.dart';
import '../models/message_translation_model.dart';
import 'api_client.dart';

class MessageService {
  const MessageService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<MessageReceiveModel>> listMessages({
    required int roomId,
    int page = 1,
  }) async {
    final response = await _apiClient.get(
      '/api/v1/messages/',
      query: {
        'room': roomId,
        'page': page,
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Load messages failed: ${response.body}');
    }

    final body = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    return body
        .whereType<Map<String, dynamic>>()
        .map(MessageReceiveModel.fromJson)
        .toList();
  }

  Future<void> sendMessage({
    required int roomId,
    required String text,
    int? replyTo,
    List<XFile> attachments = const [],
  }) async {
    Future<List<http.MultipartFile>> buildFiles() async {
      final files = <http.MultipartFile>[];
      for (final file in attachments) {
        final bytes = await file.readAsBytes();
        files.add(
          http.MultipartFile.fromBytes(
            'attachments',
            bytes,
            filename: file.name.isEmpty ? 'upload.bin' : file.name,
          ),
        );
      }
      return files;
    }

    final response = await _apiClient.postMultipart(
      '/api/v1/messages/',
      query: {'room': roomId},
      fields: {
        if (text.trim().isNotEmpty) 'message': text.trim(),
        if (replyTo != null) 'replyTo': replyTo.toString(),
      },
      buildFiles: buildFiles,
    );

    if (response.statusCode != 201) {
      final body = await response.stream.bytesToString();
      throw Exception('Send message failed: $body');
    }
  }

  Future<void> changeMessage({
    required int messageId,
    required String text,
    int? replyTo,
    List<XFile> attachments = const [],
  }) async {
    Future<List<http.MultipartFile>> buildFiles() async {
      final files = <http.MultipartFile>[];
      for (final file in attachments) {
        final bytes = await file.readAsBytes();
        files.add(
          http.MultipartFile.fromBytes(
            'attachments',
            bytes,
            filename: file.name.isEmpty ? 'upload.bin' : file.name,
          ),
        );
      }
      return files;
    }

    final response = await _apiClient.putMultipart(
      '/api/v1/messages/$messageId',
      fields: {
        if (text.trim().isNotEmpty) 'message': text.trim(),
        if (replyTo != null) 'replyTo': replyTo.toString(),
      },
      buildFiles: buildFiles,
    );

    if (response.statusCode != 204) {
      final body = await response.stream.bytesToString();
      throw Exception('Update message failed: $body');
    }
  }

  Future<void> recallMessage(int messageId) async {
    final response = await _apiClient.delete('/api/v1/messages/$messageId');
    if (response.statusCode != 204) {
      throw Exception('Recall message failed: ${response.body}');
    }
  }

  Future<void> setTypingStatus({
    required int roomId,
    required bool typing,
  }) async {
    final response = await _apiClient.postJson(
      '/api/v1/messages/typing',
      {'typing': typing},
      query: {'room': roomId},
    );

    if (response.statusCode != 204) {
      throw Exception('Set typing status failed: ${response.body}');
    }
  }

  Future<void> setReadStatus({required int roomId}) async {
    final response = await _apiClient.postJson(
      '/api/v1/messages/read',
      const {},
      query: {'room': roomId},
    );

    if (response.statusCode != 204) {
      throw Exception('Set read status failed: ${response.body}');
    }
  }

  Future<String> transcribeSpeech({
    required XFile audioFile,
    String language = 'vi',
    String? prompt,
  }) async {
    final normalizedLanguage = language.trim().isEmpty ? 'vi' : language.trim();
    final normalizedPrompt = (prompt ?? '').trim();

    Future<List<http.MultipartFile>> buildFiles() async {
      final bytes = await audioFile.readAsBytes();
      final filename = audioFile.name.trim().isEmpty
          ? 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a'
          : audioFile.name.trim();

      return [
        http.MultipartFile.fromBytes(
          'audio',
          bytes,
          filename: filename,
        ),
      ];
    }

    final streamed = await _apiClient.postMultipart(
      '/api/v1/speech-to-text',
      fields: {
        'language': normalizedLanguage,
        if (normalizedPrompt.isNotEmpty) 'prompt': normalizedPrompt,
      },
      buildFiles: buildFiles,
    );

    final payload = await streamed.stream.bytesToString();
    if (streamed.statusCode != 200) {
      throw Exception('Speech-to-text failed: $payload');
    }

    final decoded = jsonDecode(payload);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Speech-to-text failed: invalid response');
    }

    final text = (decoded['text'] ?? '').toString().trim();
    if (text.isEmpty) {
      throw Exception('Speech-to-text failed: empty transcription');
    }

    return text;
  }

  Future<MessageTranslationModel> translateMessageToVietnamese({
    required String text,
    String sourceLanguage = 'auto',
    List<String> previousMessages = const [],
  }) async {
    final normalizedText = text.trim();
    if (normalizedText.isEmpty) {
      throw Exception('Translate message failed: empty text');
    }

    final normalizedContext = previousMessages
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);

    final response = await _apiClient.postJson(
      '/api/v1/messages/translate',
      {
        'text': normalizedText,
        'targetLanguage': 'vi',
        'sourceLanguage': sourceLanguage,
        if (normalizedContext.isNotEmpty) 'previousMessages': normalizedContext,
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Translate message failed: ${response.body}');
    }

    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is! Map<String, dynamic>) {
      throw Exception('Translate message failed: invalid response');
    }

    return MessageTranslationModel.fromJson(body);
  }

  Future<MessageSummaryModel> summarizeRecentMessages({
    required List<String> messages,
    String? roomName,
  }) async {
    final normalizedMessages = messages
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);

    if (normalizedMessages.isEmpty) {
      throw Exception('Summarize failed: no messages');
    }

    final normalizedRoomName = (roomName ?? '').trim();

    final response = await _apiClient.postJson(
      '/api/v1/messages/summarize',
      {
        'messages': normalizedMessages,
        if (normalizedRoomName.isNotEmpty) 'roomName': normalizedRoomName,
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Summarize failed: ${response.body}');
    }

    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is! Map<String, dynamic>) {
      throw Exception('Summarize failed: invalid response');
    }

    return MessageSummaryModel.fromJson(body);
  }
}

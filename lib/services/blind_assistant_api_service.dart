import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../config/constants.dart';
import '../models/blind_assistant_message.dart';

class BlindAssistantApiService {
  final Dio _dio;

  BlindAssistantApiService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: AppConstants.backendBaseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 60),
            ),
          );

  Future<String> createSession() async {
    final response = await _dio.post(
      '/api/assistant/sessions',
      data: {'mode': 'blind', 'client': 'flutter', 'locale': 'zh-CN'},
    );

    final data = response.data as Map<String, dynamic>;
    return (data['session_id'] as String? ?? '').trim();
  }

  Future<BlindAssistantMessage> sendMessage({
    required String sessionId,
    required String message,
  }) async {
    final response = await _dio.post(
      '/api/assistant/chat',
      data: {
        'session_id': sessionId,
        'message': message,
        'input_type': 'text',
        'mode': 'blind',
        'expect_voice_friendly': true,
      },
    );

    final data = response.data as Map<String, dynamic>;
    final assistantMessage = data['assistant_message'];
    if (assistantMessage is! Map<String, dynamic>) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        error: 'invalid_assistant_message',
      );
    }

    return BlindAssistantMessage.fromJson(assistantMessage);
  }

  Future<String> speechToText({
    required String sessionId,
    required Uint8List audioBytes,
    required String fileName,
    required String audioFormat,
    String locale = 'zh-CN',
  }) async {
    final response = await _dio.post(
      '/api/assistant/speech-to-text',
      data: FormData.fromMap({
        'session_id': sessionId,
        'mode': 'blind',
        'locale': locale,
        'audio_format': audioFormat,
        'audio': MultipartFile.fromBytes(audioBytes, filename: fileName),
      }),
    );

    final data = response.data as Map<String, dynamic>;
    return (data['transcript'] as String? ?? '').trim();
  }

  Future<Uint8List> textToSpeech({
    required String sessionId,
    required String text,
    String voice = 'Cherry',
    String format = 'wav',
    double speakingRate = 1.0,
  }) async {
    final response = await _dio.post<List<int>>(
      '/api/assistant/text-to-speech',
      data: {
        'session_id': sessionId,
        'text': text,
        'voice': voice,
        'format': format,
        'speaking_rate': speakingRate,
      },
      options: Options(responseType: ResponseType.bytes),
    );

    final data = response.data;
    if (data == null || data.isEmpty) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        error: 'empty_tts_audio',
      );
    }

    return Uint8List.fromList(data);
  }
}

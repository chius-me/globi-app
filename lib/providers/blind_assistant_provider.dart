import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/blind_assistant_message.dart';
import '../services/blind_assistant_api_service.dart';

class BlindAssistantProvider extends ChangeNotifier {
  static const List<String> _defaultPrompts = [
    '帮我概括今天的天气提醒',
    '帮我写一段给家属的消息',
    '教我怎么安全过马路',
    '帮我整理今天要做的事',
  ];

  final BlindAssistantApiService _assistantApi;

  final List<BlindAssistantMessage> _messages = [];
  Future<void>? _initializeFuture;
  String? _sessionId;
  String? _errorMessage;
  bool _isInitializing = false;
  bool _isSending = false;

  BlindAssistantProvider({required BlindAssistantApiService assistantApi})
    : _assistantApi = assistantApi;

  List<BlindAssistantMessage> get messages => List.unmodifiable(_messages);
  List<String> get suggestedPrompts => _defaultPrompts;
  String? get errorMessage => _errorMessage;
  bool get isInitializing => _isInitializing;
  bool get isSending => _isSending;
  bool get hasMessages => _messages.isNotEmpty;

  Future<void> initialize() {
    return _initializeFuture ??= _doInitialize();
  }

  Future<void> _doInitialize() async {
    _isInitializing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _sessionId = await _assistantApi.createSession();
      if ((_sessionId ?? '').isEmpty) {
        throw StateError('empty_session_id');
      }
    } catch (error) {
      _errorMessage = _resolveErrorMessage(error, fallback: '语音助手暂时不可用，请稍后再试。');
    } finally {
      _isInitializing = false;
      _initializeFuture = null;
      notifyListeners();
    }
  }

  Future<BlindAssistantMessage?> sendMessage(String value) async {
    final message = value.trim();
    if (message.isEmpty || _isSending) {
      return null;
    }

    _messages.add(
      BlindAssistantMessage.local(
        role: BlindAssistantMessageRole.user,
        text: message,
      ),
    );
    _errorMessage = null;
    _isSending = true;
    notifyListeners();

    try {
      if ((_sessionId ?? '').isEmpty) {
        _sessionId = await _assistantApi.createSession();
      }

      if ((_sessionId ?? '').isEmpty) {
        throw StateError('empty_session_id');
      }

      final reply = await _assistantApi.sendMessage(
        sessionId: _sessionId!,
        message: message,
      );
      _messages.add(reply);
      return reply;
    } catch (error) {
      _errorMessage = _resolveErrorMessage(error, fallback: '发送失败，请检查网络后重试。');
    } finally {
      _isSending = false;
      notifyListeners();
    }

    return null;
  }

  Future<BlindAssistantMessage?> sendVoiceMessage({
    required Uint8List audioBytes,
    required String fileName,
    required String audioFormat,
  }) async {
    if (_isSending) {
      return null;
    }

    _errorMessage = null;
    _isSending = true;
    notifyListeners();

    try {
      if ((_sessionId ?? '').isEmpty) {
        _sessionId = await _assistantApi.createSession();
      }

      if ((_sessionId ?? '').isEmpty) {
        throw StateError('empty_session_id');
      }

      final transcript = await _assistantApi.speechToText(
        sessionId: _sessionId!,
        audioBytes: audioBytes,
        fileName: fileName,
        audioFormat: audioFormat,
      );

      if (transcript.isEmpty) {
        throw StateError('empty_transcript');
      }

      _messages.add(
        BlindAssistantMessage.local(
          role: BlindAssistantMessageRole.user,
          text: transcript,
        ),
      );
      notifyListeners();

      final reply = await _assistantApi.sendMessage(
        sessionId: _sessionId!,
        message: transcript,
      );
      _messages.add(reply);
      return reply;
    } catch (error) {
      _errorMessage = _resolveErrorMessage(error, fallback: '语音输入失败，请检查网络后重试。');
    } finally {
      _isSending = false;
      notifyListeners();
    }

    return null;
  }

  Future<Uint8List?> synthesizeSpeech(String text) async {
    final message = text.trim();
    if (message.isEmpty) {
      return null;
    }

    if ((_sessionId ?? '').isEmpty) {
      _sessionId = await _assistantApi.createSession();
    }

    if ((_sessionId ?? '').isEmpty) {
      throw StateError('empty_session_id');
    }

    return _assistantApi.textToSpeech(sessionId: _sessionId!, text: message);
  }

  Future<void> resetConversation() async {
    _messages.clear();
    _sessionId = null;
    _errorMessage = null;
    notifyListeners();
    await initialize();
  }

  void clearError() {
    if (_errorMessage == null) {
      return;
    }

    _errorMessage = null;
    notifyListeners();
  }

  String _resolveErrorMessage(Object error, {required String fallback}) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final detail = data['detail'];
        if (detail is String && detail.trim().isNotEmpty) {
          return detail.trim();
        }
        if (detail is Map<String, dynamic>) {
          final message = detail['message'] as String?;
          if (message != null && message.trim().isNotEmpty) {
            return message.trim();
          }
        }
        final message = data['message'] as String?;
        if (message != null && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
    }

    return fallback;
  }
}

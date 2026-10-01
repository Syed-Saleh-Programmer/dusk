import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';

class GroqApiKeyMissingException implements Exception {
  final String message;
  const GroqApiKeyMissingException([this.message = 'Groq API Key is not configured.']);

  @override
  String toString() => message;
}

class GroqApiException implements Exception {
  final int statusCode;
  final String message;
  const GroqApiException(this.statusCode, this.message);

  @override
  String toString() => 'Groq API Error ($statusCode): $message';
}

class GroqChatService {
  static final GroqChatService _instance = GroqChatService._internal();
  factory GroqChatService() => _instance;
  GroqChatService._internal();

  static const String prefApiKey = 'groq_api_key';
  static const String prefSelectedModel = 'groq_selected_model';

  // Configured Groq models
  static const String modelGptOss120b = 'openai/gpt-oss-120b';
  static const String modelGptOss20b = 'openai/gpt-oss-20b';
  static const String modelLlama33_70b = 'llama-3.3-70b-versatile';
  static const String modelLlama31_8b = 'llama-3.1-8b-instant';

  static const List<String> availableModels = [
    modelGptOss120b,
    modelGptOss20b,
    modelLlama33_70b,
    modelLlama31_8b,
  ];

  static const String defaultModel = modelGptOss120b;

  static const String _groqCompletionsUrl =
      'https://api.groq.com/openai/v1/chat/completions';

  /// Output size restriction (tokens)
  static const int maxOutputTokens = 300;

  /// Retrieves the active Groq API Key from SharedPreferences or compile-time environment.
  Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final savedKey = prefs.getString(prefApiKey)?.trim();
    if (savedKey != null && savedKey.isNotEmpty) {
      return savedKey;
    }
    const envKey = String.fromEnvironment('GROQ_API_KEY');
    if (envKey.isNotEmpty) {
      return envKey;
    }
    return null;
  }

  /// Saves a Groq API Key to local preferences.
  Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefApiKey, key.trim());
  }

  /// Clears stored Groq API Key.
  Future<void> clearApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefApiKey);
  }

  /// Gets currently selected model.
  Future<String> getSelectedModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(prefSelectedModel) ?? defaultModel;
  }

  /// Sets preferred model.
  Future<void> setSelectedModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefSelectedModel, model);
  }

  /// Sends the full conversation history + system prompt to Groq.
  /// Falls back to secondary models if primary model is unavailable.
  Future<String> sendMessage({
    required List<ChatMessage> conversationHistory,
    required String systemPrompt,
    String? modelOverride,
  }) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw const GroqApiKeyMissingException(
        'Please enter your Groq API Key to start chatting with your buddy.',
      );
    }

    final selectedModel = modelOverride ?? await getSelectedModel();

    // Model fallback sequence
    final modelsToTry = <String>{
      selectedModel,
      if (selectedModel != modelGptOss20b) modelGptOss20b,
      if (selectedModel != modelGptOss120b) modelGptOss120b,
      modelLlama33_70b,
      modelLlama31_8b,
    }.toList();

    // Build the messages payload
    final messagesPayload = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
      ...conversationHistory
          .where((m) => !m.isError && m.content.trim().isNotEmpty)
          .map((m) => {
                'role': m.role.name,
                'content': m.content.trim(),
              }),
    ];

    String? lastError;

    for (final model in modelsToTry) {
      try {
        final body = jsonEncode({
          'model': model,
          'messages': messagesPayload,
          'max_tokens': maxOutputTokens,
          'temperature': 0.3,
        });

        final response = await http
            .post(
              Uri.parse(_groqCompletionsUrl),
              headers: {
                'Authorization': 'Bearer $apiKey',
                'Content-Type': 'application/json',
              },
              body: body,
            )
            .timeout(const Duration(seconds: 25));

        if (response.statusCode == 200) {
          final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
          final choices = decoded['choices'] as List<dynamic>?;
          if (choices != null && choices.isNotEmpty) {
            final firstChoice = choices[0] as Map<String, dynamic>;
            final message = firstChoice['message'] as Map<String, dynamic>?;
            final content = message?['content']?.toString().trim() ?? '';
            if (content.isNotEmpty) {
              return content;
            }
          }
          throw const GroqApiException(200, 'Empty response received from Groq.');
        } else {
          final errBody = response.body;
          debugPrint('Groq request to $model returned ${response.statusCode}: $errBody');
          lastError = 'Groq API Error (${response.statusCode}): $errBody';

          // If unauthorized, do not try other models with the same invalid key
          if (response.statusCode == 401) {
            throw const GroqApiException(401, 'Invalid Groq API Key. Please check your credentials.');
          }
        }
      } catch (e) {
        if (e is GroqApiException && e.statusCode == 401) rethrow;
        debugPrint('Failed attempt with model $model: $e');
        lastError = e.toString();
      }
    }

    throw GroqApiException(500, lastError ?? 'Failed to reach Groq services.');
  }
}

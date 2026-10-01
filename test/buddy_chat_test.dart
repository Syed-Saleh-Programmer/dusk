import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dusk/models/chat_message.dart';
import 'package:dusk/services/buddy_context_service.dart';
import 'package:dusk/services/groq_chat_service.dart';
import 'package:dusk/ui/screens/history_screen.dart';
import 'package:dusk/ui/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatMessage Model & Serialization', () {
    test('creates ChatMessage with defaults and correctly identifies roles', () {
      final userMsg = ChatMessage(
        role: ChatMessageRole.user,
        content: 'What tasks do I have?',
      );
      expect(userMsg.isUser, isTrue);
      expect(userMsg.isAssistant, isFalse);
      expect(userMsg.isSystem, isFalse);
      expect(userMsg.isError, isFalse);
      expect(userMsg.id, isNotEmpty);

      final groqJson = userMsg.toGroqJson();
      expect(groqJson['role'], 'user');
      expect(groqJson['content'], 'What tasks do I have?');

      final assistantMsg = ChatMessage(
        role: ChatMessageRole.assistant,
        content: 'You have 2 pending tasks.',
      );
      expect(assistantMsg.isAssistant, isTrue);
      expect(assistantMsg.isUser, isFalse);

      final errorMsg = ChatMessage(
        role: ChatMessageRole.assistant,
        content: 'Network failed',
        isError: true,
      );
      expect(errorMsg.isError, isTrue);
    });

    test('serializes and deserializes to map correctly', () {
      final time = DateTime(2026, 10, 1, 12, 0);
      final msg = ChatMessage(
        id: 'msg-abc',
        role: ChatMessageRole.assistant,
        content: 'Hello, how can I help?',
        timestamp: time,
        isError: false,
      );

      final map = msg.toMap();
      final restored = ChatMessage.fromMap(map);

      expect(restored.id, 'msg-abc');
      expect(restored.role, ChatMessageRole.assistant);
      expect(restored.content, 'Hello, how can I help?');
      expect(restored.isError, isFalse);
    });
  });

  group('BuddyContextService Prompt & Guardrails', () {
    test('out of context fallback string is strictly defined', () {
      expect(
        BuddyContextService.outOfContextFallback,
        'Sorry, nothing like that in your second brain.',
      );
    });

    test('metadata label produces clean readable item counts', () {
      const meta = BuddyContextMetadata(
        dumpCount: 5,
        taskCount: 1,
        reflectionCount: 2,
        systemPrompt: 'System prompt content',
      );
      expect(meta.summaryLabel, '5 dumps · 1 task · 2 reflections');

      const singularMeta = BuddyContextMetadata(
        dumpCount: 1,
        taskCount: 1,
        reflectionCount: 1,
        systemPrompt: 'Singular',
      );
      expect(singularMeta.summaryLabel, '1 dump · 1 task · 1 reflection');
    });
  });

  group('GroqChatService Configuration & Token Restrictions', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('enforces 300 token output limit and valid models', () {
      expect(GroqChatService.maxOutputTokens, 300);
      expect(GroqChatService.defaultModel, 'openai/gpt-oss-120b');
      expect(GroqChatService.availableModels, contains('openai/gpt-oss-120b'));
      expect(GroqChatService.availableModels, contains('openai/gpt-oss-20b'));
    });

    test('throws GroqApiKeyMissingException when no API key is configured', () async {
      final service = GroqChatService();
      await service.clearApiKey();

      expect(
        () => service.sendMessage(
          conversationHistory: [
            ChatMessage(role: ChatMessageRole.user, content: 'Hi'),
          ],
          systemPrompt: 'You are Dusk Buddy',
        ),
        throwsA(isA<GroqApiKeyMissingException>()),
      );
    });

    test('persists and retrieves Groq API key in SharedPreferences', () async {
      final service = GroqChatService();
      expect(await service.getApiKey(), isNull);

      await service.saveApiKey('gsk_test123456');
      expect(await service.getApiKey(), 'gsk_test123456');

      await service.clearApiKey();
      expect(await service.getApiKey(), isNull);
    });

    test('persists and updates selected model in SharedPreferences', () async {
      final service = GroqChatService();
      expect(await service.getSelectedModel(), GroqChatService.defaultModel);

      await service.setSelectedModel('openai/gpt-oss-20b');
      expect(await service.getSelectedModel(), 'openai/gpt-oss-20b');
    });
  });

  group('DuskAiRotatingGradientButton Widget Tests', () {
    testWidgets('renders rotating gradient button with constant 56x56 size', (tester) async {
      bool tapped = false;
      const palette = DuskColorPalette.duskSunset;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DuskAiRotatingGradientButton(
              palette: palette,
              size: 56.0,
              animateRotation: false,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // Verify widget exists
      final buttonFinder = find.byType(DuskAiRotatingGradientButton);
      expect(buttonFinder, findsOneWidget);

      // Verify auto_awesome icon is rendered
      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);

      // Verify tap works
      await tester.tap(buttonFinder);
      await tester.pump();
      expect(tapped, isTrue);

      // Verify constant size (does not pulse or distort)
      final size = tester.getSize(buttonFinder);
      expect(size.width, 56.0);
      expect(size.height, 56.0);

      // Cleanly dispose repeating animation controller
      await tester.pumpWidget(const SizedBox());
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/chat_message.dart';
import '../../services/buddy_context_service.dart';
import '../../services/groq_chat_service.dart';
import '../theme/app_theme.dart';
import '../widgets/dusk_ui_components.dart';

class DuskChatScreen extends StatefulWidget {
  const DuskChatScreen({super.key});

  @override
  State<DuskChatScreen> createState() => _DuskChatScreenState();
}

class _DuskChatScreenState extends State<DuskChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final List<ChatMessage> _messages = [];
  bool _isLoadingContext = true;
  bool _isGenerating = false;
  BuddyContextMetadata? _contextMetadata;
  String? _selectedModel;
  bool _hasApiKey = false;

  static const int maxInputLength = 300;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    _initChat();
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _initChat() async {
    setState(() => _isLoadingContext = true);

    final key = await GroqChatService().getApiKey();
    final model = await GroqChatService().getSelectedModel();
    final meta = await BuddyContextService().buildSecondBrainContext();

    if (mounted) {
      setState(() {
        _hasApiKey = key != null && key.isNotEmpty;
        _selectedModel = model;
        _contextMetadata = meta;
        _isLoadingContext = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutQuad,
        );
      }
    });
  }

  void _resetChat() {
    setState(() {
      _messages.clear();
      _textController.clear();
    });
  }

  Future<void> _sendMessage([String? presetText]) async {
    final text = (presetText ?? _textController.text).trim();
    if (text.isEmpty || _isGenerating) return;

    if (!_hasApiKey) {
      _showApiKeyDialog();
      return;
    }

    final userMessage = ChatMessage(
      role: ChatMessageRole.user,
      content: text,
    );

    setState(() {
      _messages.add(userMessage);
      _isGenerating = true;
      if (presetText == null) {
        _textController.clear();
      }
    });

    _scrollToBottom();

    try {
      final systemPrompt = _contextMetadata?.systemPrompt ??
          (await BuddyContextService().buildSecondBrainContext()).systemPrompt;

      final responseText = await GroqChatService().sendMessage(
        conversationHistory: _messages,
        systemPrompt: systemPrompt,
        modelOverride: _selectedModel,
      );

      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            role: ChatMessageRole.assistant,
            content: responseText,
          ));
          _isGenerating = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            role: ChatMessageRole.assistant,
            content: e is GroqApiKeyMissingException
                ? 'Please configure your Groq API Key to chat.'
                : 'Error: ${e.toString()}',
            isError: true,
          ));
          _isGenerating = false;
        });
        _scrollToBottom();

        if (e is GroqApiKeyMissingException) {
          _showApiKeyDialog();
        }
      }
    }
  }

  void _showApiKeyDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        final p = AppTheme.of(context);
        return AlertDialog(
          backgroundColor: p.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Icon(Icons.vpn_key_rounded, color: p.primary, size: 24),
              const SizedBox(width: 10),
              Text(
                'Groq API Key',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: p.onSurface,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Paste your Groq API Key to enable instant answers from your second brain.',
                style: TextStyle(
                  fontSize: 13,
                  color: p.onSurface.withOpacity(0.7),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                obscureText: true,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'gsk_...',
                  filled: true,
                  fillColor: p.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: p.outlineVariant),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: p.onSurface.withOpacity(0.6))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: p.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () async {
                final key = controller.text.trim();
                if (key.isNotEmpty) {
                  await GroqChatService().saveApiKey(key);
                  if (mounted) {
                    setState(() => _hasApiKey = true);
                  }
                }
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Save Key'),
            ),
          ],
        );
      },
    );
  }

  void _showModelPickerSheet() {
    final p = AppTheme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: p.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Select Groq Model',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: p.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                ...GroqChatService.availableModels.map((m) {
                  final isSelected = m == (_selectedModel ?? GroqChatService.defaultModel);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: isSelected ? p.primary : p.onSurface.withOpacity(0.4),
                    ),
                    title: Text(
                      m,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: p.onSurface,
                        fontSize: 14,
                      ),
                    ),
                    onTap: () async {
                      await GroqChatService().setSelectedModel(m);
                      if (mounted) {
                        setState(() => _selectedModel = m);
                      }
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                      }
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);

    return Scaffold(
      backgroundColor: p.background,
      body: DuskAmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // 1. Top App Bar
              _buildTopBar(p),

              // 2. Context Status Pill
              if (!_isLoadingContext && _contextMetadata != null)
                _buildContextStatusBadge(p),

              // 3. Chat Messages Area
              Expanded(
                child: _isLoadingContext
                    ? _buildLoadingState(p)
                    : _messages.isEmpty
                        ? _buildEmptyState(p)
                        : _buildMessageList(p),
              ),

              // 4. Generating Indicator
              if (_isGenerating) _buildGeneratingIndicator(p),

              // 5. Input Bar with 300 char counter
              _buildInputBar(p),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(DuskColorPalette p) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          DuskCircleButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back',
            onTap: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Dusk Buddy',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: p.onSurface,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _hasApiKey ? const Color(0xFF4CAF50) : const Color(0xFFFF9800),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: _showModelPickerSheet,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          _selectedModel ?? GroqChatService.defaultModel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: p.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: p.primary),
                    ],
                  ),
                ),
              ],
            ),
          ),
          DuskCircleButton(
            icon: Icons.vpn_key_rounded,
            tooltip: 'Groq API Key',
            onTap: _showApiKeyDialog,
          ),
          const SizedBox(width: 8),
          DuskCircleButton(
            icon: Icons.refresh_rounded,
            tooltip: 'New Fresh Chat',
            onTap: _resetChat,
          ),
        ],
      ),
    );
  }

  Widget _buildContextStatusBadge(DuskColorPalette p) {
    final meta = _contextMetadata!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: p.surface.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: p.outlineVariant.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_rounded, size: 13, color: p.primary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Brain Snapshot: ${meta.summaryLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: p.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(DuskColorPalette p) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(p.primary),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Synthesizing second brain context...',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: p.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(DuskColorPalette p) {
    final samplePrompts = [
      'What are my pending tasks right now?',
      'Summarize my main captures from this past week.',
      'What were my standout insights and wins?',
      'Did I write down any ideas about projects?',
    ];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [p.primary, p.tertiary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: p.primary.withOpacity(0.3),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 30,
              ),
            ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 18),
            Text(
              'Chat with Your Buddy',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: p.onSurface,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Ask anything about your past dumps, tasks, and reflections. Dusk Buddy answers strictly from your personal second brain.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: p.onSurface.withOpacity(0.65),
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Suggestions',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: p.onSurface.withOpacity(0.5),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 10),
            ...samplePrompts.map((prompt) => _buildPromptChip(prompt, p)),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptChip(String prompt, DuskColorPalette p) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _sendMessage(prompt),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: p.surface.withOpacity(0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.outlineVariant.withValues(alpha: 0.6)),
            ),
            child: Row(
              children: [
                Icon(Icons.chat_bubble_outline_rounded, size: 16, color: p.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    prompt,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: p.onSurface.withOpacity(0.85),
                    ),
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 12, color: p.onSurface.withOpacity(0.3)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageList(DuskColorPalette p) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return _buildMessageBubble(message, p);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message, DuskColorPalette p) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [p.primary, p.tertiary],
                ),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                size: 15,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? p.primary
                    : (message.isError
                        ? const Color(0xFFFFEBEE)
                        : p.surface),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                boxShadow: isUser
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                border: isUser
                    ? null
                    : Border.all(
                        color: message.isError
                            ? const Color(0xFFEF9A9A)
                            : p.outlineVariant.withValues(alpha: 0.5),
                      ),
              ),
              child: isUser
                  ? Text(
                      message.content,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.5,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    )
                  : MarkdownBody(
                      data: message.content,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                        p: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          color: p.onSurface,
                          height: 1.45,
                        ),
                        strong: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          color: p.onSurface,
                        ),
                        listBullet: TextStyle(color: p.primary),
                        code: TextStyle(
                          fontSize: 12.5,
                          backgroundColor: p.surfaceVariant,
                          color: p.primary,
                        ),
                      ),
                    ),
            ),
          ),
          if (isUser) const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildGeneratingIndicator(DuskColorPalette p) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: p.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(p.primary),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Thinking...',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: p.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(begin: 0.6, end: 1.0),
        ],
      ),
    );
  }

  Widget _buildInputBar(DuskColorPalette p) {
    final currentLength = _textController.text.length;
    final hasText = _textController.text.trim().isNotEmpty;
    final canSend = hasText && !_isGenerating;
    final isNearLimit = currentLength >= maxInputLength - 30;

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(
          top: BorderSide(
            color: p.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: p.surfaceVariant.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: _focusNode.hasFocus
                  ? p.primary.withValues(alpha: 0.6)
                  : p.outlineVariant.withValues(alpha: 0.6),
              width: _focusNode.hasFocus ? 1.5 : 1.0,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 4, 6, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  maxLength: maxInputLength,
                  maxLengthEnforcement: MaxLengthEnforcement.enforced,
                  maxLines: 4,
                  minLines: 1,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _sendMessage(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5,
                    color: p.onSurface,
                    height: 1.35,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ask about dumps, tasks, reflections...',
                    hintStyle: TextStyle(
                      fontSize: 13.5,
                      color: p.onSurface.withValues(alpha: 0.4),
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(vertical: 9),
                  ),
                ),
              ),
              if (hasText) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, right: 4),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      _textController.clear();
                      setState(() {});
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: p.onSurface.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 13,
                        color: p.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ],
              if (currentLength > 0) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 9, right: 6),
                  child: Text(
                    '$currentLength/$maxInputLength',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: isNearLimit
                          ? (currentLength >= maxInputLength ? Colors.red : Colors.orange)
                          : p.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: canSend
                        ? () {
                            HapticFeedback.lightImpact();
                            _sendMessage();
                          }
                        : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: canSend
                            ? LinearGradient(
                                colors: [p.primary, p.tertiary],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: canSend
                            ? null
                            : p.onSurface.withValues(alpha: 0.08),
                        boxShadow: canSend
                            ? [
                                BoxShadow(
                                  color: p.primary.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: _isGenerating
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(p.primary),
                                ),
                              )
                            : Icon(
                                Icons.arrow_upward_rounded,
                                color: canSend
                                    ? Colors.white
                                    : p.onSurface.withValues(alpha: 0.3),
                                size: 20,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

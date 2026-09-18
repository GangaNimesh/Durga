import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/legal_chat_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/onboarding_colors.dart';
import 'legal_response_card.dart';

class LegalChatView extends StatefulWidget {
  final VoidCallback? onClose;
  final ScrollController? parentScrollController;

  const LegalChatView({
    super.key,
    this.onClose,
    this.parentScrollController,
  });

  @override
  State<LegalChatView> createState() => _LegalChatViewState();
}

class _LegalChatViewState extends State<LegalChatView> {
  final TextEditingController _controller = TextEditingController();
  late final ScrollController _scrollController;
  final FocusNode _focusNode = FocusNode();

  List<_ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.parentScrollController ?? ScrollController();
    _initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    if (widget.parentScrollController == null) {
      _scrollController.dispose();
    }
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    await LegalChatService.instance.init();

    // Load existing messages from Supabase
    try {
      final history = await SupabaseService.instance.getChatHistory();
      final loaded = history.reversed.map((msg) => _ChatMessage(
        role: msg['role'] as String,
        content: msg['content'] as String,
        timestamp: DateTime.parse(msg['created_at']),
      )).toList();

      if (mounted) {
        setState(() {
          _messages = loaded;
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? presetText]) async {
    final text = (presetText ?? _controller.text).trim();
    if (text.isEmpty || _isSending) return;

    if (presetText == null) {
      _controller.clear();
    }

    setState(() {
      _messages.add(_ChatMessage(role: 'user', content: text, timestamp: DateTime.now()));
      _isSending = true;
    });
    _scrollToBottom();

    final response = await LegalChatService.instance.sendMessage(text);

    if (mounted) {
      setState(() {
        _messages.add(_ChatMessage(role: 'assistant', content: response, timestamp: DateTime.now()));
        _isSending = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _clearChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: OnboardingColors.surface,
        title: Text('Clear Chat History', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'This will permanently delete your legal chat history from this device.',
          style: GoogleFonts.inter(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Clear', style: GoogleFonts.inter(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await LegalChatService.instance.clearHistory();
      if (mounted) {
        setState(() => _messages = []);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Chat Header ──
        _buildHeader(),

        // ── Messages / Loading ──
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: OnboardingColors.coral))
              : _messages.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: _messages.length + (_isSending ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length && _isSending) {
                          return _buildTypingIndicator();
                        }
                        return _buildMessageBubble(_messages[index]);
                      },
                    ),
        ),

        // ── Input Bar ──
        _buildInputBar(),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1A22),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: OnboardingColors.coral.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.balance, color: OnboardingColors.coral, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Legal Help AI',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Indian Women\'s Rights • Instant Guidance',
                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.white54, size: 20),
              tooltip: 'Clear Chat',
              onPressed: _clearChat,
            ),
          if (widget.onClose != null)
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 28),
              tooltip: 'Collapse',
              onPressed: widget.onClose,
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: OnboardingColors.coral.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.balance_rounded, color: OnboardingColors.coral, size: 40),
          ),
          const SizedBox(height: 16),
          Text(
            'Know Your Rights',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ask questions about filing FIRs, workplace harassment, domestic violence protections, or legal aid.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildSuggestionChip('How do I file a Zero FIR?'),
              _buildSuggestionChip('My rights under Domestic Violence Act'),
              _buildSuggestionChip('Workplace sexual harassment: POSH rules'),
              _buildSuggestionChip('What is Section 498A IPC?'),
              _buildSuggestionChip('How to get free legal aid in India?'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return InkWell(
      onTap: () => _sendMessage(text),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: OnboardingColors.coral.withValues(alpha: 0.3)),
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(color: OnboardingColors.coral, fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage message) {
    final isUser = message.role == 'user';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: OnboardingColors.coral.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.balance_rounded, color: OnboardingColors.coral, size: 14),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isUser
                    ? OnboardingColors.coral.withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                border: isUser
                    ? Border.all(color: OnboardingColors.coral.withValues(alpha: 0.4))
                    : Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: isUser
                  ? SelectableText(
                      message.content,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    )
                  : LegalResponseCard(
                      rawResponse: message.content,
                      onFaqSelected: (faq) => _sendMessage(faq),
                    ),
            ),
          ),
          if (isUser) const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: OnboardingColors.coral.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.balance, color: OnboardingColors.coral, size: 14),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 5),
                _buildDot(1),
                const SizedBox(width: 5),
                _buildDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: Duration(milliseconds: 600 + (index * 200)),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: OnboardingColors.coral.withValues(alpha: 0.8),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 14,
        right: 8,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom > 0
            ? 10
            : MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1A22),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white12),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'Ask about your legal rights...',
                  hintStyle: GoogleFonts.inter(color: Colors.white30, fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: _isSending ? null : () => _sendMessage(),
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: _isSending ? Colors.white12 : OnboardingColors.coral,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.send_rounded,
                color: _isSending ? Colors.white38 : Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String role;
  final String content;
  final DateTime timestamp;

  _ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
  });
}

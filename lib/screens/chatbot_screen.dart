import 'package:flutter/material.dart';

import '../models/dklic_document.dart';
import '../services/dklic_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/logout_action.dart';
import '../widgets/notification_bell.dart';

const _kSuggestions = [
  'What documents are required for delayed birth registration?',
  'Explain divorce arbitration council procedure',
  'Which authority approves delayed birth registration?',
  'What are nikah registration requirements?',
];

class _ChatMessage {
  _ChatMessage({required this.fromUser, required this.text, this.sources = const []});

  final bool fromUser;
  final String text;
  final List<DklicAiSource> sources;
}

/// Local Government Chatbot — the same AI Legal Intelligence Assistant that
/// backs DKLIC's askAi endpoint, presented as a standalone full-page chat
/// (mirrors web's Chatbot.jsx, which is just <AiAssistant /> full-page).
class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key, required this.role, required this.user});

  final String role;
  final Map<String, dynamic> user;

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  final List<_ChatMessage> _messages = [
    _ChatMessage(
      fromUser: false,
      text: 'Hello! I am the LGCD AI Legal Intelligence Assistant.\n\n'
          'I answer questions exclusively from documents uploaded to the DKLIC Knowledge Repository — Rules, Gazettes, '
          'Circulars, SOPs, and official orders. I always cite the exact source document and reference number.\n\n'
          'How can I assist you today?',
    ),
  ];
  bool _thinking = false;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  Future<void> _ask([String? preset]) async {
    final query = (preset ?? _inputController.text).trim();
    if (query.isEmpty || _thinking) return;

    setState(() {
      _messages.add(_ChatMessage(fromUser: true, text: query));
      _thinking = true;
    });
    _inputController.clear();
    _scrollToEnd();

    try {
      final answer = await DklicService.instance.askAi(role: widget.role, query: query);
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(fromUser: false, text: answer.answer, sources: answer.sources));
        _thinking = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(fromUser: false, text: 'Something went wrong. Please try again.'));
        _thinking = false;
      });
    }
    _scrollToEnd();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(
        title: const Text('Local Government Chatbot'),
        actions: const [NotificationBell(), LogoutAction()],
      ),
      drawer: AppDrawer(role: widget.role, currentKey: 'chatbot', user: widget.user),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Answers are sourced exclusively from the DKLIC Knowledge Repository',
                style: TextStyle(fontSize: 11.5, color: AppColors.inkMuted),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              itemCount: _messages.length + (_thinking ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == _messages.length) return const _ThinkingBubble();
                return _MessageBubble(message: _messages[i]);
              },
            ),
          ),
          if (_messages.length <= 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _kSuggestions
                    .map((s) => OutlinedButton(
                          onPressed: () => _ask(s),
                          style: OutlinedButton.styleFrom(
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            textStyle: const TextStyle(fontSize: 11),
                          ),
                          child: Text(s),
                        ))
                    .toList(),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      enabled: !_thinking,
                      onSubmitted: (_) => _ask(),
                      decoration: const InputDecoration(hintText: 'Ask about rules, gazettes, circulars…', isDense: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _thinking ? null : () => _ask(),
                    icon: const Icon(Icons.send_rounded, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.fromUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary500 : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isUser ? null : Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(fontSize: 13, height: 1.4, color: isUser ? Colors.white : AppColors.ink),
            ),
            if (message.sources.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.only(top: 8),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('📎 SOURCES CITED', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.info)),
                      const SizedBox(height: 4),
                      ...message.sources.map((s) => Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              '• ${s.title}${s.referenceNo != null ? ' [${s.referenceNo}]' : ''}',
                              style: const TextStyle(fontSize: 10.5, color: AppColors.inkMuted),
                            ),
                          )),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text('🤖 Searching knowledge repository…', style: TextStyle(fontSize: 12.5, color: AppColors.inkMuted)),
      ),
    );
  }
}

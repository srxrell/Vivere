import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:ui';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';

// Класс для хранения сообщений чата
class Message {
  final String text;
  final bool isUser;
  Message(this.text, this.isUser);
}

class AiChat extends StatefulWidget {
  const AiChat({super.key});

  @override
  State<AiChat> createState() => _AiChatState();
}

class _AiChatState extends State<AiChat> {
  // Константы стиля
  static const Color _primaryColor = Color(0xFF0B1E39);
  static const Color _accentColor = Color(0xFF2C3DBF);

  // URL API
  final String apiUrl = "https://towards-project.onrender.com/ask";

  // Быстрые вопросы
  final List<String> _quickPrompts = [
    'Как улучшить ситуацию с пожарами?',
    'Как исправить положение с нехваткой воды?',
    'Как правильно бороться с перенаселением?',
  ];

  final List<Message> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  // Отправка сообщения
  Future<void> _sendMessage(String prompt) async {
    if (prompt.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(Message(prompt, true));
      _isLoading = true;
    });
    _scrollToBottom();

    _textController.clear();

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"prompt": prompt}),
      );

      String aiResponse;

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        String? responseCandidate = data['reply'] as String?;

        if (responseCandidate == null) {
          final candidates = data['candidates'] as List<dynamic>?;
          final candidate =
              candidates?.isNotEmpty == true ? candidates![0] : null;
          final content = candidate?['content'] as Map<String, dynamic>?;
          final parts = content?['parts'] as List<dynamic>?;
          final part = parts?.isNotEmpty == true ? parts![0] : null;
          responseCandidate = part?['text'] as String?;
        }

        aiResponse =
            responseCandidate ?? 'Извините, произошла ошибка парсинга ответа.';
      } else {
        aiResponse =
            'Ошибка API: ${response.statusCode}. Не удалось получить ответ.';
      }

      setState(() {
        _isLoading = false;
        _messages.add(Message(aiResponse, false));
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _messages.add(Message(
            'Ошибка сети: Проверьте URL ($apiUrl) и соединение.\nОшибка: $e',
            false));
      });
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    Timer(const Duration(milliseconds: 50), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Виджет одного сообщения
  Widget _buildMessageBubble(Message message) {
    final styleSheet = MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: const TextStyle(color: Colors.white, fontSize: 16),
      strong: const TextStyle(
          color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
      listBullet: const TextStyle(color: Colors.white, fontSize: 16),
      h1: const TextStyle(
          color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
      h2: const TextStyle(
          color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
    );

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(message.isUser ? 20 : 5),
          bottomRight: Radius.circular(message.isUser ? 5 : 20),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(message.isUser ? 20 : 5),
                bottomRight: Radius.circular(message.isUser ? 5 : 20),
              ),
            ),
            child: message.isUser
                ? Text(
                    message.text,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  )
                : MarkdownBody(
                    data: message.text,
                    selectable: true,
                    styleSheet: styleSheet,
                  ),
          ),
        ),
      ),
    );
  }

  // Виджет быстрых вопросов
  Widget _buildQuickPrompts() {
    return _messages.isNotEmpty
        ? const SizedBox.shrink()
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: _quickPrompts.map((prompt) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                        side: const BorderSide(color: Colors.white10),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 15, vertical: 10),
                    ),
                    onPressed: () => _sendMessage(prompt),
                    child: Text(
                      prompt,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 15),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _primaryColor,
      body: SafeArea(
        child: Column(
          children: [
            // ---------- HEADER ----------
            if (_messages.isEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Container(
                  width: MediaQuery.of(context).size.width,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgPicture.asset(
                        "assets/images/Leading-icon.svg", // твой SVG
                        width: 58,
                        height: 58,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "Forecaster AI",
                        style: GoogleFonts.geologica(
                          textStyle: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (_messages.isEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Explore\ninfinite knowleɡde\nabout all\ncities",
                    style: GoogleFonts.geologica(
                      textStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 46,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),

            // ---------- CHAT ----------
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _messages.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length) {
                    return const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.0,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                    );
                  }
                  return _buildMessageBubble(_messages[index]);
                },
              ),
            ),

            // ---------- QUICK PROMPTS + INPUT ----------
            _buildQuickPrompts(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 15),
                        hintText: 'Ask AI about cities',
                        hintStyle:
                            TextStyle(color: Colors.white.withOpacity(0.5)),
                        border: InputBorder.none,
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 10.0),
                          child: Icon(Icons.search,
                              color: Colors.white.withOpacity(0.7)),
                        ),
                        suffixIcon: _isLoading
                            ? null
                            : IconButton(
                                icon:
                                    const Icon(Icons.send, color: _accentColor),
                                onPressed: () =>
                                    _sendMessage(_textController.text),
                              ),
                      ),
                      onSubmitted: _sendMessage,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

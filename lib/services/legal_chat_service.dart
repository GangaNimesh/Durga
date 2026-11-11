import 'dart:async';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import 'supabase_service.dart';

class LegalChatService {
  LegalChatService._();
  static final LegalChatService instance = LegalChatService._();

  GenerativeModel? _model;
  ChatSession? _chat;
  String _knowledgeBase = '';
  bool _isInitialized = false;

  bool get isReady => _isInitialized && _model != null && _chat != null;

  Future<void> init({bool force = false}) async {
    if (_isInitialized && !force && _model != null && _chat != null) return;

    try {
      // Load the reference knowledge base from assets
      if (_knowledgeBase.isEmpty) {
        try {
          _knowledgeBase = await rootBundle.loadString('assets/legal/indian_women_legal_guide.md');
          debugPrint("Knowledge base loaded: ${_knowledgeBase.length} chars");
        } catch (e) {
          debugPrint("Knowledge base load note: $e");
        }
      }

      // Ensure dotenv is loaded
      var apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
      if (apiKey.isEmpty) {
        try {
          await dotenv.load(fileName: ".env");
          apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
        } catch (e) {
          debugPrint("dotenv reload error: $e");
        }
      }

      if (apiKey.isEmpty) {
        debugPrint("GEMINI_API_KEY not found in .env — Durga AI assistant will be unavailable.");
        _isInitialized = false;
        return;
      }

      _model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: apiKey,
        systemInstruction: Content.system(_buildSystemPrompt()),
        generationConfig: GenerationConfig(
          temperature: 0.7,
          topP: 0.95,
          maxOutputTokens: 2048,
        ),
      );

      // Load existing chat history from Supabase
      List<Map<String, dynamic>> history = [];
      try {
        history = await SupabaseService.instance.getChatHistory();
      } catch (e) {
        debugPrint("Chat history load note: $e");
      }

      final historyContent = history.reversed.map((msg) {
        final role = msg['role'] == 'user' ? 'user' : 'model';
        return Content(role, [TextPart(msg['content'] as String)]);
      }).toList();

      _chat = _model!.startChat(history: historyContent);
      _isInitialized = true;
      debugPrint("Durga AI assistant initialized successfully with gemini-1.5-flash.");
    } catch (e) {
      debugPrint("Durga AI assistant init error: $e");
      _isInitialized = false;
    }
  }

  String _buildSystemPrompt() {
    return '''You are Durga AI Assistant, an intelligent safety, legal, and general guidance assistant embedded in the Durga women's safety app.

Your role:
- Provide accurate, helpful, empathetic, and clear guidance on safety, emergency protocols, Indian women's rights, and everyday questions.
- Help users understand their safety options, emergency features in Durga, and legal protections under Indian law (BNS/IPC, BNSS/CrPC, POSH, domestic violence acts, cyber harassment protections).
- When discussing legal matters, cite relevant sections clearly and plainly.
- For general safety questions or day-to-day guidance, provide clear, supportive, and practical advice.
- Be compassionate, reassuring, and concise. Avoid intimidating walls of text.
- Fully fluent in both English and Telugu: If the user writes in Telugu or asks for assistance in Telugu, respond entirely in natural, reassuring Telugu.

CRITICAL OUTPUT FORMAT REQUIREMENTS:
Always organize your response into the following explicit blocks so the mobile UI can render interactive dropdown accordions and clickable FAQ chips:

[SUMMARY]
Write a clear, empathetic 2-3 sentence direct answer or takeaway. This is immediately visible to the user.

[EMERGENCY]
(Include this block ONLY if the situation involves immediate danger, violence, or urgent risk. If not urgent, OMIT this block.)
Write 1 brief emergency instruction mentioning helplines: 112 (National Emergency) or 181 (Women Helpline).

[STEPS]
(Include if there are practical steps or advice to take.)
1. Step Title: Practical, clear explanation of what to do.
2. Step Title: Practical, clear explanation of what to do.

[LAWS]
(Include if relevant legal sections or official protections apply.)
- Section / Law Name: Plain-English explanation of rights guaranteed or penalties under this law.

[FAQS]
(Always include 2-3 common follow-up questions the user might want to ask next.)
- Follow-up question 1?
- Follow-up question 2?

IMPORTANT:
- Do NOT use markdown code blocks around the tags.
- Always include [SUMMARY] and [FAQS].
- You are an informational AI assistant, not a licensed lawyer.

REFERENCE KNOWLEDGE BASE:
$_knowledgeBase
''';
  }

  /// Send a message and get a response
  Future<String> sendMessage(String userMessage) async {
    if (_model == null || _chat == null) {
      await init(force: true);
    }

    if (_model == null || _chat == null) {
      return "Durga AI Assistant is unavailable. Please verify your GEMINI_API_KEY in the .env file and restart the app.";
    }

    try {
      // Save user message to Supabase
      try {
        await SupabaseService.instance.saveChatMessage(
          role: 'user',
          content: userMessage,
        );
      } catch (e) {
        debugPrint("Chat save error (Supabase): $e");
      }

      // Send to Gemini
      final response = await _chat!.sendMessage(Content.text(userMessage));
      final responseText = response.text ?? "I'm sorry, I couldn't generate a response. Please try again.";

      // Save assistant response to Supabase
      try {
        await SupabaseService.instance.saveChatMessage(
          role: 'assistant',
          content: responseText,
        );
      } catch (e) {
        debugPrint("Chat response save error (Supabase): $e");
      }

      return responseText;
    } catch (e) {
      debugPrint("Durga AI assistant message error: $e");
      return "Sorry, I encountered an error. Please check your internet connection or API key and try again.\n\nError: $e";
    }
  }

  /// Clear chat history and start fresh
  Future<void> clearHistory() async {
    try {
      await SupabaseService.instance.clearChatHistory();
    } catch (e) {
      debugPrint("Clear history error: $e");
    }
    if (_model != null) {
      _chat = _model!.startChat();
    }
  }
}

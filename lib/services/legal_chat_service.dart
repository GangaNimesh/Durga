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

  bool get isReady => _isInitialized && _model != null;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Load the legal knowledge base from assets
      _knowledgeBase = await rootBundle.loadString('assets/legal/indian_women_legal_guide.md');
      debugPrint("Legal knowledge base loaded: ${_knowledgeBase.length} chars");

      final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
      if (apiKey.isEmpty) {
        debugPrint("GEMINI_API_KEY not set — Legal chatbot will be unavailable.");
        _isInitialized = true;
        return;
      }

      _model = GenerativeModel(
        model: 'gemini-2.0-flash',
        apiKey: apiKey,
        systemInstruction: Content.system(_buildSystemPrompt()),
        generationConfig: GenerationConfig(
          temperature: 0.7,
          topP: 0.95,
          maxOutputTokens: 2048,
        ),
      );

      // Load existing chat history from Supabase
      final history = await SupabaseService.instance.getChatHistory();
      final historyContent = history.reversed.map((msg) {
        final role = msg['role'] == 'user' ? 'user' : 'model';
        return Content(role, [TextPart(msg['content'] as String)]);
      }).toList();

      _chat = _model!.startChat(history: historyContent);
      _isInitialized = true;
      debugPrint("Legal chat service initialized successfully.");
    } catch (e) {
      debugPrint("Legal chat service init error: $e");
      _isInitialized = true; // Mark as initialized even on error so we don't retry forever
    }
  }

  String _buildSystemPrompt() {
    return '''You are Durga Legal Assistant, an AI legal advisor specializing in Indian women's rights and safety laws. You are embedded in the Durga women's safety app.

Your role:
- Provide accurate, empathetic, and clear legal guidance based on Indian law.
- Help women understand their legal rights, step-by-step procedures for filing complaints, and available protections.
- Always cite specific laws, sections, and acts when relevant (IPC/BNS, CrPC/BNSS, PWDVA, POSH, etc.).
- Be compassionate, reassuring, and concise. Avoid intimidating walls of text.

CRITICAL OUTPUT FORMAT REQUIREMENTS:
Always organize your response into the following explicit blocks so the mobile UI can render interactive dropdown accordions and clickable FAQ chips:

[SUMMARY]
Write a clear, empathetic 2-3 sentence direct answer or takeaway. This is immediately visible to the user.

[EMERGENCY]
(Include this block ONLY if the situation involves immediate danger, violence, or urgent risk. If not urgent, OMIT this block.)
Write 1 brief emergency instruction mentioning helplines: 112 (National Emergency) or 181 (Women Helpline).

[STEPS]
(Include if there are practical steps to take, e.g. filing FIR, collecting evidence, lodging complaint.)
1. Step Title: Practical, clear explanation of what to do.
2. Step Title: Practical, clear explanation of what to do.
3. Step Title: Practical, clear explanation of what to do.

[LAWS]
(Include relevant legal sections and protections.)
- Section / Act Name: Plain-English explanation of rights guaranteed or penalties under this law.
- Section / Act Name: Plain-English explanation of rights guaranteed or penalties under this law.

[FAQS]
(Always include 2-3 common follow-up questions the user might want to ask next.)
- Follow-up question 1?
- Follow-up question 2?
- Follow-up question 3?

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
      return "Legal chatbot is unavailable. Please add your Gemini API key in the .env file.";
    }

    try {
      // Save user message to Supabase
      await SupabaseService.instance.saveChatMessage(
        role: 'user',
        content: userMessage,
      );

      // Send to Gemini
      final response = await _chat!.sendMessage(Content.text(userMessage));
      final responseText = response.text ?? "I'm sorry, I couldn't generate a response. Please try again.";

      // Save assistant response to Supabase
      await SupabaseService.instance.saveChatMessage(
        role: 'assistant',
        content: responseText,
      );

      return responseText;
    } catch (e) {
      debugPrint("Legal chat error: $e");
      return "Sorry, I encountered an error. Please check your internet connection and try again.\n\nError: $e";
    }
  }

  /// Clear chat history and start fresh
  Future<void> clearHistory() async {
    await SupabaseService.instance.clearChatHistory();
    if (_model != null) {
      _chat = _model!.startChat();
    }
  }
}

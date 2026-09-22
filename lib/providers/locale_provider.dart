import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage {
  english,
  telugu,
}

class LocaleProvider extends ChangeNotifier {
  static const String _prefKey = 'selected_app_language';

  AppLanguage _language = AppLanguage.english;

  LocaleProvider() {
    _loadFromPrefs();
  }

  AppLanguage get language => _language;
  bool get isTelugu => _language == AppLanguage.telugu;
  bool get isEnglish => _language == AppLanguage.english;

  String get languageCode => isTelugu ? 'te' : 'en';

  static LocaleProvider of(BuildContext context, {bool listen = true}) {
    return Provider.of<LocaleProvider>(context, listen: listen);
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString(_prefKey);
      if (savedCode == 'te') {
        _language = AppLanguage.telugu;
        notifyListeners();
      } else if (savedCode == 'en') {
        _language = AppLanguage.english;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading language preference: $e');
    }
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (_language == language) return;
    _language = language;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, language == AppLanguage.telugu ? 'te' : 'en');
    } catch (e) {
      debugPrint('Error saving language preference: $e');
    }
  }

  void toggleLanguage() {
    if (_language == AppLanguage.english) {
      setLanguage(AppLanguage.telugu);
    } else {
      setLanguage(AppLanguage.english);
    }
  }

  /// Get localized string by key
  String tr(String key) {
    final entry = AppTranslations.strings[key];
    if (entry == null) return key;
    return isTelugu ? entry.te : entry.en;
  }
}

class TranslationEntry {
  final String en;
  final String te;

  const TranslationEntry({required this.en, required this.te});
}

class AppTranslations {
  static const Map<String, TranslationEntry> strings = {
    // ── Onboarding ──
    'onboarding_skip': TranslationEntry(
      en: 'Skip',
      te: 'దాటవేయి',
    ),
    'onboarding_later': TranslationEntry(
      en: "I'll do this later",
      te: 'నేను తర్వాత చేస్తాను',
    ),
    'onboarding_get_started': TranslationEntry(
      en: 'Get Started',
      te: 'ప్రారంభించండి',
    ),
    'onboarding_continue': TranslationEntry(
      en: 'Continue',
      te: 'కొనసాగించండి',
    ),
    'onboarding_finish_setup': TranslationEntry(
      en: 'Finish Setup  →',
      te: 'సెటప్ పూర్తిచేయండి  →',
    ),
    'onboarding_slide1_title': TranslationEntry(
      en: 'Safety Is A State\nOf Mind.',
      te: 'భద్రత అనేది ఒక\nమానసిక స్థితి.',
    ),
    'onboarding_slide1_body': TranslationEntry(
      en: 'Empower your journey with intuitive control and community-backed protection.',
      te: 'సురక్షిత ప్రయాణం కోసం సాంకేతిక భద్రత మరియు సమాజం ఇచ్చే రక్షణను అనుభవించండి.',
    ),
    'onboarding_slide2_title': TranslationEntry(
      en: "Let's Get You\nSet Up.",
      te: 'మీ వివరాలను\nనమోదు చేయండి.',
    ),
    'onboarding_slide2_body': TranslationEntry(
      en: 'We need your details to keep you and your contacts connected in emergencies.',
      te: 'అత్యవసర సమయాల్లో మీ పరిచయస్తులను సంప్రదించడానికి మీ వివరాలు అవసరం.',
    ),
    'onboarding_full_name': TranslationEntry(
      en: 'Full Name',
      te: 'పూర్తి పేరు',
    ),
    'onboarding_full_name_hint': TranslationEntry(
      en: 'Jane Doe',
      te: 'మీ పేరు నమోదు చేయండి',
    ),
    'onboarding_phone': TranslationEntry(
      en: 'Phone Number',
      te: 'ఫోన్ నంబర్',
    ),
    'onboarding_phone_hint': TranslationEntry(
      en: '+91 98765 43210',
      te: '+91 98765 43210',
    ),
    'onboarding_email': TranslationEntry(
      en: 'Email Address',
      te: 'ఈమెయిల్ చిరునామా',
    ),
    'onboarding_email_hint': TranslationEntry(
      en: 'jane@example.com',
      te: 'jane@example.com',
    ),
    'onboarding_slide3_title': TranslationEntry(
      en: 'Add Someone\nYou Trust.',
      te: 'మీకు నమ్మకమైన వారిని\nచేర్చండి.',
    ),
    'onboarding_slide3_body': TranslationEntry(
      en: "They'll be the first to know if you need help.",
      te: 'మీకు సహాయం అవసరమైనప్పుడు ముందుగా వీరికి సమాచారం అందుతుంది.',
    ),
    'onboarding_add_trusted_contact': TranslationEntry(
      en: 'Add Trusted Contact',
      te: 'విశ్వసనీయ పరిచయాన్ని జోడించండి',
    ),
    'onboarding_max_contacts': TranslationEntry(
      en: 'Maximum 3 contacts allowed.',
      te: 'గరిష్టంగా 3 పరిచయాలు మాత్రమే అనుమతించబడతాయి.',
    ),

    // ── Homepage Header & Greetings ──
    'home_profile': TranslationEntry(
      en: 'Profile',
      te: 'ప్రొఫైల్',
    ),
    'home_greeting_prefix': TranslationEntry(
      en: 'Hi',
      te: 'నమస్తే',
    ),
    'home_safety_priority': TranslationEntry(
      en: 'Your safety is our priority today.',
      te: 'మీ భద్రతే నేడు మా ప్రథమ ప్రాధాన్యత.',
    ),

    // ── SOS Button & Warning ──
    'sos_tap_for_sos': TranslationEntry(
      en: 'TAP FOR SOS',
      te: 'సహాయం కోసం తాకండి',
    ),
    'sos_hold_voice': TranslationEntry(
      en: 'Hold for voice • Tap to call 100',
      te: 'వాయిస్ కోసం నొక్కి ఉంచండి • 100 కి కాల్ చేయడానికి తాకండి',
    ),
    'sos_emergency_alert': TranslationEntry(
      en: 'Emergency Help Alert',
      te: 'అత్యవసర సహాయ హెచ్చరిక',
    ),
    'sos_alert_desc': TranslationEntry(
      en: 'Tap SOS to immediately dial 100. Press volume-down to speak a voice trigger.',
      te: '100 కి కాల్ చేయడానికి SOS ని నొక్కండి. వాయిస్ ఆదేశాల కోసం వాల్యూమ్-డౌన్ నొక్కి పట్టుకోండి.',
    ),

    // ── Quick Actions ──
    'quick_actions': TranslationEntry(
      en: 'Quick Actions',
      te: 'శీఘ్ర చర్యలు',
    ),
    'action_fake_call': TranslationEntry(
      en: 'Fake Call',
      te: 'నకిలీ కాల్',
    ),
    'action_fake_call_desc': TranslationEntry(
      en: 'Simulate incoming call to exit awkward or risky situations.',
      te: 'ఇబ్బందికరమైన పరిస్థితుల నుండి తప్పుకోవడానికి కాల్ అనుకరించండి.',
    ),
    'action_instant_video': TranslationEntry(
      en: 'Instant Video',
      te: 'తక్షణ వీడియో',
    ),
    'action_instant_video_desc': TranslationEntry(
      en: 'Record & upload evidence video immediately.',
      te: 'తక్షణమే సాక్ష్యం వీడియోను రికార్డ్ చేసి అప్‌లోడ్ చేయండి.',
    ),
    'action_silent_record': TranslationEntry(
      en: 'Silent Record',
      te: 'నిశ్శబ్ద రికార్డింగ్',
    ),
    'action_recording_active': TranslationEntry(
      en: 'Recording Audio...',
      te: 'ఆడియో రికార్డ్ అవుతోంది...',
    ),
    'action_silent_record_desc': TranslationEntry(
      en: 'Discreetly record background audio without alerting anyone.',
      te: 'ఎవరికీ తెలియకుండా రహస్యంగా నేపధ్య ఆడియోను రికార్డ్ చేయండి.',
    ),
    'action_solo_trip': TranslationEntry(
      en: 'Solo Trip',
      te: 'సోలో ట్రిప్',
    ),
    'action_solo_trip_desc': TranslationEntry(
      en: 'Automatic check-in timer that alerts contacts if you do not arrive.',
      te: 'మీరు చేరకపోతే మీ పరిచయస్తులను హెచ్చరించే ఆటో చెక్-ఇన్ టైమర్.',
    ),
    'solotrip_active': TranslationEntry(
      en: 'Active',
      te: 'యాక్టివ్',
    ),
    'solotrip_end': TranslationEntry(
      en: 'End Trip',
      te: 'ట్రిప్ ముగించు',
    ),

    // ── Helplines ──
    'helplines_title': TranslationEntry(
      en: 'Emergency Helplines',
      te: 'అత్యవసర హెల్ప్‌లైన్లు',
    ),
    'helplines_call_tag': TranslationEntry(
      en: 'CALL',
      te: 'కాల్',
    ),
    'helpline_police': TranslationEntry(
      en: 'Police Control Room',
      te: 'పోలీస్ కంట్రోల్ రూమ్',
    ),
    'helpline_police_desc': TranslationEntry(
      en: 'Immediate emergency response (24x7)',
      te: 'తక్షణ అత్యవసర సహాయం (24 గంటలు)',
    ),
    'helpline_women': TranslationEntry(
      en: 'Women Helpline',
      te: 'మహిళా హెల్ప్‌లైన్',
    ),
    'helpline_women_desc': TranslationEntry(
      en: 'Specialized support for women in distress (24x7)',
      te: 'మహిళల సంక్షేమం మరియు ప్రత్యేక సహాయం (24 గంటలు)',
    ),
    'helpline_ncw': TranslationEntry(
      en: 'National Commission for Women',
      te: 'జాతీయ మహిళా కమిషన్',
    ),
    'helpline_ncw_desc': TranslationEntry(
      en: 'NCW domestic violence & harassment helpline',
      te: 'గృహహింస మరియు వేధింపుల ఫిర్యాదుల విభాగం',
    ),
    'helpline_ambulance': TranslationEntry(
      en: 'Ambulance & Medical',
      te: 'అంబులెన్స్ & వైద్య సహాయం',
    ),
    'helpline_ambulance_desc': TranslationEntry(
      en: 'National medical emergency response service',
      te: 'జాతీయ వైద్య అత్యవసర ప్రతిస్పందన సేవ',
    ),
    'helpline_child': TranslationEntry(
      en: 'Childline',
      te: 'చైల్డ్‌లైన్',
    ),
    'helpline_child_desc': TranslationEntry(
      en: 'Protection and assistance for children in need',
      te: 'పిల్లల సంరక్షణ మరియు రక్షణ విభాగం',
    ),

    // ── Bottom Drawer & 5 Action Buttons ──
    'drawer_swipe_up': TranslationEntry(
      en: 'Swipe up for Legal AI Guide',
      te: 'లీగల్ AI గైడ్ కోసం పైకి స్వైప్ చేయండి',
    ),
    'drawer_action_safezone': TranslationEntry(
      en: 'Safe Zone',
      te: 'సురక్షిత జోన్',
    ),
    'drawer_action_voicelog': TranslationEntry(
      en: 'Voice Log',
      te: 'వాయిస్ లాగ్',
    ),
    'drawer_action_fakecall': TranslationEntry(
      en: 'Fake Call',
      te: 'నకిలీ కాల్',
    ),
    'drawer_action_video': TranslationEntry(
      en: 'Video',
      te: 'వీడియో',
    ),
    'drawer_action_solotrip': TranslationEntry(
      en: 'Solo Trip',
      te: 'సోలో ట్రిప్',
    ),

    // ── Legal Chat / Drawer ──
    'legal_chat_title': TranslationEntry(
      en: 'Durga Legal Assistant',
      te: 'దుర్గా లీగల్ అసిస్టెంట్',
    ),
    'legal_chat_subtitle': TranslationEntry(
      en: 'Know your rights under Indian Law',
      te: 'భారతీయ చట్టాల ప్రకారం మీ హక్కులను తెలుసుకోండి',
    ),
    'legal_chat_disclaimer': TranslationEntry(
      en: 'Informational legal assistance, not a substitute for a lawyer.',
      te: 'ఇది సమాచార సంబంధిత సహాయం మాత్రమే, న్యాయవాది సలహాకు ప్రత్యామ్నాయం కాదు.',
    ),
    'legal_chat_ask_hint': TranslationEntry(
      en: 'Ask a legal question in English or తెలుగు...',
      te: 'తెలుగు లేదా ఇంగ్లీషులో న్యాయపరమైన ప్రశ్న అడగండి...',
    ),
    'legal_accordion_steps': TranslationEntry(
      en: 'Step-by-Step Procedure',
      te: 'దశలవారీ విధానం',
    ),
    'legal_accordion_laws': TranslationEntry(
      en: 'Applicable Laws & Sections',
      te: 'వర్తించే చట్టాలు & సెక్షన్లు',
    ),
    'legal_accordion_faqs': TranslationEntry(
      en: 'Related FAQs & Follow-ups',
      te: 'సంబంధిత ప్రశ్నలు & సమాధానాలు',
    ),
    'legal_tab_fir': TranslationEntry(
      en: 'Zero FIR Rights',
      te: 'జీరో ఎఫ్ఐఆర్ హక్కులు',
    ),
    'legal_tab_posh': TranslationEntry(
      en: 'Workplace POSH',
      te: 'కార్యాలయ POSH చట్టం',
    ),
    'legal_tab_domestic': TranslationEntry(
      en: 'Domestic Violence',
      te: 'గృహహింస చట్టం',
    ),
    'legal_tab_stalking': TranslationEntry(
      en: 'Stalking & Cyber',
      te: 'సైబర్ క్రైమ్ & వేధింపులు',
    ),
  };
}

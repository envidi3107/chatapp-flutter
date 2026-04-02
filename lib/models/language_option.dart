/// Model for a language option with country flag and name.
class LanguageOption {
  const LanguageOption({
    required this.code,
    required this.name,
    required this.flagEmoji,
    required this.nativeName,
  });

  /// ISO 639-1 language code (e.g. 'vi', 'en', 'ja')
  final String code;

  /// English name
  final String name;

  /// Flag emoji representing the primary country of the language
  final String flagEmoji;

  /// Native language name
  final String nativeName;

  // Static list of popular languages with preset data
  // Flag emoji + ISO 639-1 code + English/native names
  static const List<LanguageOption> popular = [
    LanguageOption(code: 'vi', name: 'Vietnamese', flagEmoji: '🇻🇳', nativeName: 'Tiếng Việt'),
    LanguageOption(code: 'en', name: 'English', flagEmoji: '🇺🇸', nativeName: 'English'),
    LanguageOption(code: 'zh', name: 'Chinese', flagEmoji: '🇨🇳', nativeName: '中文'),
    LanguageOption(code: 'ja', name: 'Japanese', flagEmoji: '🇯🇵', nativeName: '日本語'),
    LanguageOption(code: 'ko', name: 'Korean', flagEmoji: '🇰🇷', nativeName: '한국어'),
    LanguageOption(code: 'fr', name: 'French', flagEmoji: '🇫🇷', nativeName: 'Français'),
    LanguageOption(code: 'de', name: 'German', flagEmoji: '🇩🇪', nativeName: 'Deutsch'),
    LanguageOption(code: 'es', name: 'Spanish', flagEmoji: '🇪🇸', nativeName: 'Español'),
    LanguageOption(code: 'pt', name: 'Portuguese', flagEmoji: '🇧🇷', nativeName: 'Português'),
    LanguageOption(code: 'it', name: 'Italian', flagEmoji: '🇮🇹', nativeName: 'Italiano'),
    LanguageOption(code: 'ru', name: 'Russian', flagEmoji: '🇷🇺', nativeName: 'Русский'),
    LanguageOption(code: 'ar', name: 'Arabic', flagEmoji: '🇸🇦', nativeName: 'العربية'),
    LanguageOption(code: 'hi', name: 'Hindi', flagEmoji: '🇮🇳', nativeName: 'हिंदी'),
    LanguageOption(code: 'th', name: 'Thai', flagEmoji: '🇹🇭', nativeName: 'ภาษาไทย'),
    LanguageOption(code: 'id', name: 'Indonesian', flagEmoji: '🇮🇩', nativeName: 'Bahasa Indonesia'),
    LanguageOption(code: 'ms', name: 'Malay', flagEmoji: '🇲🇾', nativeName: 'Bahasa Melayu'),
    LanguageOption(code: 'tr', name: 'Turkish', flagEmoji: '🇹🇷', nativeName: 'Türkçe'),
    LanguageOption(code: 'nl', name: 'Dutch', flagEmoji: '🇳🇱', nativeName: 'Nederlands'),
    LanguageOption(code: 'pl', name: 'Polish', flagEmoji: '🇵🇱', nativeName: 'Polski'),
    LanguageOption(code: 'sv', name: 'Swedish', flagEmoji: '🇸🇪', nativeName: 'Svenska'),
  ];

  static LanguageOption? findByCode(String? code) {
    if (code == null) return null;
    try {
      return popular.firstWhere((l) => l.code == code);
    } catch (_) {
      return null;
    }
  }
}

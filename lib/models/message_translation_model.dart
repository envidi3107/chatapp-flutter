class MessageTranslationModel {
  const MessageTranslationModel({
    required this.translatedText,
    required this.detectedSourceLanguage,
    required this.targetLanguage,
  });

  final String translatedText;
  final String? detectedSourceLanguage;
  final String targetLanguage;

  factory MessageTranslationModel.fromJson(Map<String, dynamic> json) {
    return MessageTranslationModel(
      translatedText: (json['translatedText'] ?? '').toString(),
      detectedSourceLanguage:
          (json['detectedSourceLanguage'] ?? '').toString().trim().isEmpty
              ? null
              : json['detectedSourceLanguage'].toString(),
      targetLanguage: (json['targetLanguage'] ?? '').toString(),
    );
  }
}

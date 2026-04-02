class MessageSummaryModel {
  const MessageSummaryModel({
    required this.summary,
    required this.messageCount,
  });

  final String summary;
  final int messageCount;

  factory MessageSummaryModel.fromJson(Map<String, dynamic> json) {
    return MessageSummaryModel(
      summary: (json['summary'] ?? '').toString(),
      messageCount: (json['messageCount'] as num?)?.toInt() ?? 0,
    );
  }
}

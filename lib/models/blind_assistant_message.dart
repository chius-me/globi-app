enum BlindAssistantMessageRole { user, assistant }

class BlindAssistantMessage {
  final String id;
  final BlindAssistantMessageRole role;
  final String text;
  final DateTime createdAt;

  const BlindAssistantMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
  });

  bool get isUser => role == BlindAssistantMessageRole.user;

  factory BlindAssistantMessage.local({
    required BlindAssistantMessageRole role,
    required String text,
  }) {
    final now = DateTime.now();
    return BlindAssistantMessage(
      id: '${role.name}-${now.microsecondsSinceEpoch}',
      role: role,
      text: text,
      createdAt: now,
    );
  }

  factory BlindAssistantMessage.fromJson(Map<String, dynamic> json) {
    final roleValue = (json['role'] as String? ?? 'assistant').toLowerCase();
    final createdAtValue = json['created_at'] as String?;

    return BlindAssistantMessage(
      id: (json['id'] ?? 'assistant-${DateTime.now().microsecondsSinceEpoch}')
          .toString(),
      role: roleValue == 'user'
          ? BlindAssistantMessageRole.user
          : BlindAssistantMessageRole.assistant,
      text: (json['text'] as String? ?? '').trim(),
      createdAt: DateTime.tryParse(createdAtValue ?? '') ?? DateTime.now(),
    );
  }
}

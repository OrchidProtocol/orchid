import 'package:orchid/orchid/orchid.dart';

enum ChatMessageSource { client, provider, system, internal }

class ChatMessage {
  final ChatMessageSource source;
  final String sourceName;
  final String message;
  final Map<String, dynamic>? metadata;

  // The modelId of the model that generated this message
  final String? modelId;

  // The name of the model that generated this message
  final String? modelName;

  ChatMessage({
    required this.source,
    required this.message,
    this.metadata,
    this.sourceName = '',
    this.modelId,
    this.modelName,
  });

  String? get displayName {
    if (source == ChatMessageSource.provider && modelName != null) {
      return modelName;
    }
    if (sourceName.isNotEmpty) {
      return sourceName;
    }
    log('Returning null displayName'); // See when we hit this case
    return null;
  }

  String formatUsage() {
    if (metadata == null || !metadata!.containsKey('usage')) {
      return '';
    }

    final usage = metadata!['usage'];
    if (usage == null) {
      return '';
    }

    final prompt = usage['prompt_tokens'] ?? 0;
    final completion = usage['completion_tokens'] ?? 0;

    if (prompt == 0 && completion == 0) {
      return '';
    }

    return 'tokens: $prompt in, $completion out';
  }

  // Clone this immutable object with new values for some fields
  ChatMessage copyWith({
    ChatMessageSource? source,
    String? message,
    Map<String, dynamic>? metadata,
    String? sourceName,
    String? modelId,
    String? modelName,
  }) {
    return ChatMessage(
      source: source ?? this.source,
      message: message ?? this.message,
      metadata: metadata ?? this.metadata,
      sourceName: sourceName ?? this.sourceName,
      modelId: modelId ?? this.modelId,
      modelName: modelName ?? this.modelName,
    );
  }

  @override
  String toString() {
    return 'ChatMessage(source: $source, modelId: $modelId, model: $modelName, msg: ${message.substring(0, message.length.clamp(0, 50))}...)';
  }
}

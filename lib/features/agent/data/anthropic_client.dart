import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/api_config.dart';

/// Stream event types from Claude
sealed class StreamEvent {}

/// Text delta - yield immediately for TTS
class TextDelta extends StreamEvent {
  final String text;
  TextDelta(this.text);
}

/// Tool use detected - complete tool call to execute
class ToolUseEvent extends StreamEvent {
  final String id;
  final String name;
  final Map<String, dynamic> input;
  ToolUseEvent({required this.id, required this.name, required this.input});
}

/// Message complete
class MessageEnd extends StreamEvent {}

/// Anthropic API client for Claude with streaming support
class AnthropicClient {
  String get _apiKey => dotenv.env['ANTHROPIC_API_KEY'] ?? '';

  /// Create a message with Claude (non-streaming, for tool calls)
  Future<Map<String, dynamic>> createMessage({
    required String system,
    required List<Map<String, dynamic>> messages,
    required List<Map<String, dynamic>> tools,
    int maxTokens = ApiConfig.maxTokens,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception('ANTHROPIC_API_KEY not configured');
    }

    final response = await http.post(
      Uri.parse('${ApiConfig.anthropicBaseUrl}/v1/messages'),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': _apiKey,
        'anthropic-version': ApiConfig.anthropicApiVersion,
      },
      body: jsonEncode({
        'model': ApiConfig.claudeModel,
        'max_tokens': maxTokens,
        'system': system,
        'messages': messages,
        'tools': tools,
      }),
    );

    if (response.statusCode != 200) {
      debugPrint('Anthropic API error: ${response.body}');
      throw Exception('API error: ${response.statusCode}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Create a streaming message with tool support
  /// Yields StreamEvent: TextDelta for text, ToolUseEvent for tool calls, MessageEnd when done
  Stream<StreamEvent> createMessageStreamWithTools({
    required String system,
    required List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>>? tools,
    int maxTokens = ApiConfig.maxTokens,
  }) async* {
    if (_apiKey.isEmpty) {
      throw Exception('ANTHROPIC_API_KEY not configured');
    }

    final request = http.Request(
      'POST',
      Uri.parse('${ApiConfig.anthropicBaseUrl}/v1/messages'),
    );

    request.headers.addAll({
      'Content-Type': 'application/json',
      'x-api-key': _apiKey,
      'anthropic-version': ApiConfig.anthropicApiVersion,
    });

    final body = {
      'model': ApiConfig.claudeModel,
      'max_tokens': maxTokens,
      'system': system,
      'messages': messages,
      'stream': true,
    };
    if (tools != null && tools.isNotEmpty) {
      body['tools'] = tools;
    }

    request.body = jsonEncode(body);

    final response = await http.Client().send(request);

    if (response.statusCode != 200) {
      final errorBody = await response.stream.bytesToString();
      debugPrint('Anthropic streaming error: $errorBody');
      throw Exception('API error: ${response.statusCode}');
    }

    // Track current tool being built
    String? currentToolId;
    String? currentToolName;
    StringBuffer toolInputBuffer = StringBuffer();

    // Parse SSE stream
    await for (final chunk in response.stream.transform(utf8.decoder)) {
      for (final line in chunk.split('\n')) {
        if (line.startsWith('data: ')) {
          final data = line.substring(6);
          if (data == '[DONE]') {
            yield MessageEnd();
            return;
          }

          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            final type = json['type'] as String?;

            if (type == 'content_block_start') {
              final contentBlock = json['content_block'] as Map<String, dynamic>?;
              if (contentBlock != null) {
                final blockType = contentBlock['type'] as String?;
                if (blockType == 'tool_use') {
                  currentToolId = contentBlock['id'] as String?;
                  currentToolName = contentBlock['name'] as String?;
                  toolInputBuffer.clear();
                }
              }
            } else if (type == 'content_block_delta') {
              final delta = json['delta'] as Map<String, dynamic>?;
              if (delta != null) {
                final deltaType = delta['type'] as String?;
                if (deltaType == 'text_delta') {
                  final text = delta['text'] as String?;
                  if (text != null) {
                    yield TextDelta(text);
                  }
                } else if (deltaType == 'input_json_delta') {
                  final partialJson = delta['partial_json'] as String?;
                  if (partialJson != null) {
                    toolInputBuffer.write(partialJson);
                  }
                }
              }
            } else if (type == 'content_block_stop') {
              // If we were building a tool call, emit it now
              if (currentToolId != null && currentToolName != null) {
                Map<String, dynamic> input = {};
                final inputStr = toolInputBuffer.toString();
                if (inputStr.isNotEmpty) {
                  try {
                    input = jsonDecode(inputStr) as Map<String, dynamic>;
                  } catch (e) {
                    debugPrint('Failed to parse tool input: $inputStr');
                  }
                }
                yield ToolUseEvent(
                  id: currentToolId!,
                  name: currentToolName!,
                  input: input,
                );
                currentToolId = null;
                currentToolName = null;
                toolInputBuffer.clear();
              }
            } else if (type == 'message_stop') {
              yield MessageEnd();
            }
          } catch (e) {
            // Skip malformed JSON
            debugPrint('SSE parse error: $e');
          }
        }
      }
    }
  }
}

/// Content block types from Claude response
class ContentBlock {
  final String type;
  final String? text;
  final String? id;
  final String? name;
  final Map<String, dynamic>? input;

  ContentBlock({
    required this.type,
    this.text,
    this.id,
    this.name,
    this.input,
  });

  factory ContentBlock.fromJson(Map<String, dynamic> json) {
    return ContentBlock(
      type: json['type'] as String,
      text: json['text'] as String?,
      id: json['id'] as String?,
      name: json['name'] as String?,
      input: json['input'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'type': type};
    if (text != null) map['text'] = text;
    if (id != null) map['id'] = id;
    if (name != null) map['name'] = name;
    if (input != null) map['input'] = input;
    return map;
  }
}

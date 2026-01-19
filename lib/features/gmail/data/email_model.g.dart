// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'email_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AttachmentImpl _$$AttachmentImplFromJson(Map<String, dynamic> json) =>
    _$AttachmentImpl(
      id: json['id'] as String,
      filename: json['filename'] as String,
      mimeType: json['mimeType'] as String,
      size: (json['size'] as num).toInt(),
    );

Map<String, dynamic> _$$AttachmentImplToJson(_$AttachmentImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'filename': instance.filename,
      'mimeType': instance.mimeType,
      'size': instance.size,
    };

_$EmailImpl _$$EmailImplFromJson(Map<String, dynamic> json) => _$EmailImpl(
      id: json['id'] as String,
      threadId: json['threadId'] as String,
      subject: json['subject'] as String,
      sender: json['sender'] as String,
      to: json['to'] as String?,
      snippet: json['snippet'] as String,
      body: json['body'] as String?,
      bodyHtml: json['bodyHtml'] as String?,
      date: json['date'] as String?,
      isUnread: json['isUnread'] as bool? ?? false,
      labelIds: (json['labelIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      attachments: (json['attachments'] as List<dynamic>?)
              ?.map((e) => Attachment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$$EmailImplToJson(_$EmailImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'threadId': instance.threadId,
      'subject': instance.subject,
      'sender': instance.sender,
      'to': instance.to,
      'snippet': instance.snippet,
      'body': instance.body,
      'bodyHtml': instance.bodyHtml,
      'date': instance.date,
      'isUnread': instance.isUnread,
      'labelIds': instance.labelIds,
      'attachments': instance.attachments,
    };

_$EmailLabelImpl _$$EmailLabelImplFromJson(Map<String, dynamic> json) =>
    _$EmailLabelImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String? ?? 'user',
    );

Map<String, dynamic> _$$EmailLabelImplToJson(_$EmailLabelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'type': instance.type,
    };

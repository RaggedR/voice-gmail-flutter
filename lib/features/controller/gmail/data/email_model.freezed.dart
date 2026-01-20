// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'email_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Attachment _$AttachmentFromJson(Map<String, dynamic> json) {
  return _Attachment.fromJson(json);
}

/// @nodoc
mixin _$Attachment {
  String get id => throw _privateConstructorUsedError;
  String get filename => throw _privateConstructorUsedError;
  String get mimeType => throw _privateConstructorUsedError;
  int get size => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $AttachmentCopyWith<Attachment> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AttachmentCopyWith<$Res> {
  factory $AttachmentCopyWith(
          Attachment value, $Res Function(Attachment) then) =
      _$AttachmentCopyWithImpl<$Res, Attachment>;
  @useResult
  $Res call({String id, String filename, String mimeType, int size});
}

/// @nodoc
class _$AttachmentCopyWithImpl<$Res, $Val extends Attachment>
    implements $AttachmentCopyWith<$Res> {
  _$AttachmentCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? filename = null,
    Object? mimeType = null,
    Object? size = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      filename: null == filename
          ? _value.filename
          : filename // ignore: cast_nullable_to_non_nullable
              as String,
      mimeType: null == mimeType
          ? _value.mimeType
          : mimeType // ignore: cast_nullable_to_non_nullable
              as String,
      size: null == size
          ? _value.size
          : size // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AttachmentImplCopyWith<$Res>
    implements $AttachmentCopyWith<$Res> {
  factory _$$AttachmentImplCopyWith(
          _$AttachmentImpl value, $Res Function(_$AttachmentImpl) then) =
      __$$AttachmentImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, String filename, String mimeType, int size});
}

/// @nodoc
class __$$AttachmentImplCopyWithImpl<$Res>
    extends _$AttachmentCopyWithImpl<$Res, _$AttachmentImpl>
    implements _$$AttachmentImplCopyWith<$Res> {
  __$$AttachmentImplCopyWithImpl(
      _$AttachmentImpl _value, $Res Function(_$AttachmentImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? filename = null,
    Object? mimeType = null,
    Object? size = null,
  }) {
    return _then(_$AttachmentImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      filename: null == filename
          ? _value.filename
          : filename // ignore: cast_nullable_to_non_nullable
              as String,
      mimeType: null == mimeType
          ? _value.mimeType
          : mimeType // ignore: cast_nullable_to_non_nullable
              as String,
      size: null == size
          ? _value.size
          : size // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AttachmentImpl implements _Attachment {
  const _$AttachmentImpl(
      {required this.id,
      required this.filename,
      required this.mimeType,
      required this.size});

  factory _$AttachmentImpl.fromJson(Map<String, dynamic> json) =>
      _$$AttachmentImplFromJson(json);

  @override
  final String id;
  @override
  final String filename;
  @override
  final String mimeType;
  @override
  final int size;

  @override
  String toString() {
    return 'Attachment(id: $id, filename: $filename, mimeType: $mimeType, size: $size)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AttachmentImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.filename, filename) ||
                other.filename == filename) &&
            (identical(other.mimeType, mimeType) ||
                other.mimeType == mimeType) &&
            (identical(other.size, size) || other.size == size));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, id, filename, mimeType, size);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$AttachmentImplCopyWith<_$AttachmentImpl> get copyWith =>
      __$$AttachmentImplCopyWithImpl<_$AttachmentImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AttachmentImplToJson(
      this,
    );
  }
}

abstract class _Attachment implements Attachment {
  const factory _Attachment(
      {required final String id,
      required final String filename,
      required final String mimeType,
      required final int size}) = _$AttachmentImpl;

  factory _Attachment.fromJson(Map<String, dynamic> json) =
      _$AttachmentImpl.fromJson;

  @override
  String get id;
  @override
  String get filename;
  @override
  String get mimeType;
  @override
  int get size;
  @override
  @JsonKey(ignore: true)
  _$$AttachmentImplCopyWith<_$AttachmentImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Email _$EmailFromJson(Map<String, dynamic> json) {
  return _Email.fromJson(json);
}

/// @nodoc
mixin _$Email {
  String get id => throw _privateConstructorUsedError;
  String get threadId => throw _privateConstructorUsedError;
  String get subject => throw _privateConstructorUsedError;
  String get sender => throw _privateConstructorUsedError;
  String? get to =>
      throw _privateConstructorUsedError; // Recipient - important for sent emails
  String get snippet => throw _privateConstructorUsedError;
  String? get body => throw _privateConstructorUsedError;
  String? get bodyHtml => throw _privateConstructorUsedError;
  String? get date => throw _privateConstructorUsedError;
  bool get isUnread => throw _privateConstructorUsedError;
  List<String> get labelIds => throw _privateConstructorUsedError;
  List<Attachment> get attachments => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $EmailCopyWith<Email> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EmailCopyWith<$Res> {
  factory $EmailCopyWith(Email value, $Res Function(Email) then) =
      _$EmailCopyWithImpl<$Res, Email>;
  @useResult
  $Res call(
      {String id,
      String threadId,
      String subject,
      String sender,
      String? to,
      String snippet,
      String? body,
      String? bodyHtml,
      String? date,
      bool isUnread,
      List<String> labelIds,
      List<Attachment> attachments});
}

/// @nodoc
class _$EmailCopyWithImpl<$Res, $Val extends Email>
    implements $EmailCopyWith<$Res> {
  _$EmailCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? threadId = null,
    Object? subject = null,
    Object? sender = null,
    Object? to = freezed,
    Object? snippet = null,
    Object? body = freezed,
    Object? bodyHtml = freezed,
    Object? date = freezed,
    Object? isUnread = null,
    Object? labelIds = null,
    Object? attachments = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      threadId: null == threadId
          ? _value.threadId
          : threadId // ignore: cast_nullable_to_non_nullable
              as String,
      subject: null == subject
          ? _value.subject
          : subject // ignore: cast_nullable_to_non_nullable
              as String,
      sender: null == sender
          ? _value.sender
          : sender // ignore: cast_nullable_to_non_nullable
              as String,
      to: freezed == to
          ? _value.to
          : to // ignore: cast_nullable_to_non_nullable
              as String?,
      snippet: null == snippet
          ? _value.snippet
          : snippet // ignore: cast_nullable_to_non_nullable
              as String,
      body: freezed == body
          ? _value.body
          : body // ignore: cast_nullable_to_non_nullable
              as String?,
      bodyHtml: freezed == bodyHtml
          ? _value.bodyHtml
          : bodyHtml // ignore: cast_nullable_to_non_nullable
              as String?,
      date: freezed == date
          ? _value.date
          : date // ignore: cast_nullable_to_non_nullable
              as String?,
      isUnread: null == isUnread
          ? _value.isUnread
          : isUnread // ignore: cast_nullable_to_non_nullable
              as bool,
      labelIds: null == labelIds
          ? _value.labelIds
          : labelIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
      attachments: null == attachments
          ? _value.attachments
          : attachments // ignore: cast_nullable_to_non_nullable
              as List<Attachment>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$EmailImplCopyWith<$Res> implements $EmailCopyWith<$Res> {
  factory _$$EmailImplCopyWith(
          _$EmailImpl value, $Res Function(_$EmailImpl) then) =
      __$$EmailImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String threadId,
      String subject,
      String sender,
      String? to,
      String snippet,
      String? body,
      String? bodyHtml,
      String? date,
      bool isUnread,
      List<String> labelIds,
      List<Attachment> attachments});
}

/// @nodoc
class __$$EmailImplCopyWithImpl<$Res>
    extends _$EmailCopyWithImpl<$Res, _$EmailImpl>
    implements _$$EmailImplCopyWith<$Res> {
  __$$EmailImplCopyWithImpl(
      _$EmailImpl _value, $Res Function(_$EmailImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? threadId = null,
    Object? subject = null,
    Object? sender = null,
    Object? to = freezed,
    Object? snippet = null,
    Object? body = freezed,
    Object? bodyHtml = freezed,
    Object? date = freezed,
    Object? isUnread = null,
    Object? labelIds = null,
    Object? attachments = null,
  }) {
    return _then(_$EmailImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      threadId: null == threadId
          ? _value.threadId
          : threadId // ignore: cast_nullable_to_non_nullable
              as String,
      subject: null == subject
          ? _value.subject
          : subject // ignore: cast_nullable_to_non_nullable
              as String,
      sender: null == sender
          ? _value.sender
          : sender // ignore: cast_nullable_to_non_nullable
              as String,
      to: freezed == to
          ? _value.to
          : to // ignore: cast_nullable_to_non_nullable
              as String?,
      snippet: null == snippet
          ? _value.snippet
          : snippet // ignore: cast_nullable_to_non_nullable
              as String,
      body: freezed == body
          ? _value.body
          : body // ignore: cast_nullable_to_non_nullable
              as String?,
      bodyHtml: freezed == bodyHtml
          ? _value.bodyHtml
          : bodyHtml // ignore: cast_nullable_to_non_nullable
              as String?,
      date: freezed == date
          ? _value.date
          : date // ignore: cast_nullable_to_non_nullable
              as String?,
      isUnread: null == isUnread
          ? _value.isUnread
          : isUnread // ignore: cast_nullable_to_non_nullable
              as bool,
      labelIds: null == labelIds
          ? _value._labelIds
          : labelIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
      attachments: null == attachments
          ? _value._attachments
          : attachments // ignore: cast_nullable_to_non_nullable
              as List<Attachment>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$EmailImpl implements _Email {
  const _$EmailImpl(
      {required this.id,
      required this.threadId,
      required this.subject,
      required this.sender,
      this.to,
      required this.snippet,
      this.body,
      this.bodyHtml,
      this.date,
      this.isUnread = false,
      final List<String> labelIds = const [],
      final List<Attachment> attachments = const []})
      : _labelIds = labelIds,
        _attachments = attachments;

  factory _$EmailImpl.fromJson(Map<String, dynamic> json) =>
      _$$EmailImplFromJson(json);

  @override
  final String id;
  @override
  final String threadId;
  @override
  final String subject;
  @override
  final String sender;
  @override
  final String? to;
// Recipient - important for sent emails
  @override
  final String snippet;
  @override
  final String? body;
  @override
  final String? bodyHtml;
  @override
  final String? date;
  @override
  @JsonKey()
  final bool isUnread;
  final List<String> _labelIds;
  @override
  @JsonKey()
  List<String> get labelIds {
    if (_labelIds is EqualUnmodifiableListView) return _labelIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_labelIds);
  }

  final List<Attachment> _attachments;
  @override
  @JsonKey()
  List<Attachment> get attachments {
    if (_attachments is EqualUnmodifiableListView) return _attachments;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_attachments);
  }

  @override
  String toString() {
    return 'Email(id: $id, threadId: $threadId, subject: $subject, sender: $sender, to: $to, snippet: $snippet, body: $body, bodyHtml: $bodyHtml, date: $date, isUnread: $isUnread, labelIds: $labelIds, attachments: $attachments)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EmailImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.threadId, threadId) ||
                other.threadId == threadId) &&
            (identical(other.subject, subject) || other.subject == subject) &&
            (identical(other.sender, sender) || other.sender == sender) &&
            (identical(other.to, to) || other.to == to) &&
            (identical(other.snippet, snippet) || other.snippet == snippet) &&
            (identical(other.body, body) || other.body == body) &&
            (identical(other.bodyHtml, bodyHtml) ||
                other.bodyHtml == bodyHtml) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.isUnread, isUnread) ||
                other.isUnread == isUnread) &&
            const DeepCollectionEquality().equals(other._labelIds, _labelIds) &&
            const DeepCollectionEquality()
                .equals(other._attachments, _attachments));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      threadId,
      subject,
      sender,
      to,
      snippet,
      body,
      bodyHtml,
      date,
      isUnread,
      const DeepCollectionEquality().hash(_labelIds),
      const DeepCollectionEquality().hash(_attachments));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$EmailImplCopyWith<_$EmailImpl> get copyWith =>
      __$$EmailImplCopyWithImpl<_$EmailImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$EmailImplToJson(
      this,
    );
  }
}

abstract class _Email implements Email {
  const factory _Email(
      {required final String id,
      required final String threadId,
      required final String subject,
      required final String sender,
      final String? to,
      required final String snippet,
      final String? body,
      final String? bodyHtml,
      final String? date,
      final bool isUnread,
      final List<String> labelIds,
      final List<Attachment> attachments}) = _$EmailImpl;

  factory _Email.fromJson(Map<String, dynamic> json) = _$EmailImpl.fromJson;

  @override
  String get id;
  @override
  String get threadId;
  @override
  String get subject;
  @override
  String get sender;
  @override
  String? get to;
  @override // Recipient - important for sent emails
  String get snippet;
  @override
  String? get body;
  @override
  String? get bodyHtml;
  @override
  String? get date;
  @override
  bool get isUnread;
  @override
  List<String> get labelIds;
  @override
  List<Attachment> get attachments;
  @override
  @JsonKey(ignore: true)
  _$$EmailImplCopyWith<_$EmailImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$EmailPreview {
  String get id => throw _privateConstructorUsedError;
  String get subject => throw _privateConstructorUsedError;
  String get senderName => throw _privateConstructorUsedError;
  String get senderEmail => throw _privateConstructorUsedError;
  String get snippet => throw _privateConstructorUsedError;
  String get dateFormatted => throw _privateConstructorUsedError;
  bool get isUnread => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $EmailPreviewCopyWith<EmailPreview> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EmailPreviewCopyWith<$Res> {
  factory $EmailPreviewCopyWith(
          EmailPreview value, $Res Function(EmailPreview) then) =
      _$EmailPreviewCopyWithImpl<$Res, EmailPreview>;
  @useResult
  $Res call(
      {String id,
      String subject,
      String senderName,
      String senderEmail,
      String snippet,
      String dateFormatted,
      bool isUnread});
}

/// @nodoc
class _$EmailPreviewCopyWithImpl<$Res, $Val extends EmailPreview>
    implements $EmailPreviewCopyWith<$Res> {
  _$EmailPreviewCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? subject = null,
    Object? senderName = null,
    Object? senderEmail = null,
    Object? snippet = null,
    Object? dateFormatted = null,
    Object? isUnread = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      subject: null == subject
          ? _value.subject
          : subject // ignore: cast_nullable_to_non_nullable
              as String,
      senderName: null == senderName
          ? _value.senderName
          : senderName // ignore: cast_nullable_to_non_nullable
              as String,
      senderEmail: null == senderEmail
          ? _value.senderEmail
          : senderEmail // ignore: cast_nullable_to_non_nullable
              as String,
      snippet: null == snippet
          ? _value.snippet
          : snippet // ignore: cast_nullable_to_non_nullable
              as String,
      dateFormatted: null == dateFormatted
          ? _value.dateFormatted
          : dateFormatted // ignore: cast_nullable_to_non_nullable
              as String,
      isUnread: null == isUnread
          ? _value.isUnread
          : isUnread // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$EmailPreviewImplCopyWith<$Res>
    implements $EmailPreviewCopyWith<$Res> {
  factory _$$EmailPreviewImplCopyWith(
          _$EmailPreviewImpl value, $Res Function(_$EmailPreviewImpl) then) =
      __$$EmailPreviewImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String subject,
      String senderName,
      String senderEmail,
      String snippet,
      String dateFormatted,
      bool isUnread});
}

/// @nodoc
class __$$EmailPreviewImplCopyWithImpl<$Res>
    extends _$EmailPreviewCopyWithImpl<$Res, _$EmailPreviewImpl>
    implements _$$EmailPreviewImplCopyWith<$Res> {
  __$$EmailPreviewImplCopyWithImpl(
      _$EmailPreviewImpl _value, $Res Function(_$EmailPreviewImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? subject = null,
    Object? senderName = null,
    Object? senderEmail = null,
    Object? snippet = null,
    Object? dateFormatted = null,
    Object? isUnread = null,
  }) {
    return _then(_$EmailPreviewImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      subject: null == subject
          ? _value.subject
          : subject // ignore: cast_nullable_to_non_nullable
              as String,
      senderName: null == senderName
          ? _value.senderName
          : senderName // ignore: cast_nullable_to_non_nullable
              as String,
      senderEmail: null == senderEmail
          ? _value.senderEmail
          : senderEmail // ignore: cast_nullable_to_non_nullable
              as String,
      snippet: null == snippet
          ? _value.snippet
          : snippet // ignore: cast_nullable_to_non_nullable
              as String,
      dateFormatted: null == dateFormatted
          ? _value.dateFormatted
          : dateFormatted // ignore: cast_nullable_to_non_nullable
              as String,
      isUnread: null == isUnread
          ? _value.isUnread
          : isUnread // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$EmailPreviewImpl implements _EmailPreview {
  const _$EmailPreviewImpl(
      {required this.id,
      required this.subject,
      required this.senderName,
      required this.senderEmail,
      required this.snippet,
      required this.dateFormatted,
      required this.isUnread});

  @override
  final String id;
  @override
  final String subject;
  @override
  final String senderName;
  @override
  final String senderEmail;
  @override
  final String snippet;
  @override
  final String dateFormatted;
  @override
  final bool isUnread;

  @override
  String toString() {
    return 'EmailPreview(id: $id, subject: $subject, senderName: $senderName, senderEmail: $senderEmail, snippet: $snippet, dateFormatted: $dateFormatted, isUnread: $isUnread)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EmailPreviewImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.subject, subject) || other.subject == subject) &&
            (identical(other.senderName, senderName) ||
                other.senderName == senderName) &&
            (identical(other.senderEmail, senderEmail) ||
                other.senderEmail == senderEmail) &&
            (identical(other.snippet, snippet) || other.snippet == snippet) &&
            (identical(other.dateFormatted, dateFormatted) ||
                other.dateFormatted == dateFormatted) &&
            (identical(other.isUnread, isUnread) ||
                other.isUnread == isUnread));
  }

  @override
  int get hashCode => Object.hash(runtimeType, id, subject, senderName,
      senderEmail, snippet, dateFormatted, isUnread);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$EmailPreviewImplCopyWith<_$EmailPreviewImpl> get copyWith =>
      __$$EmailPreviewImplCopyWithImpl<_$EmailPreviewImpl>(this, _$identity);
}

abstract class _EmailPreview implements EmailPreview {
  const factory _EmailPreview(
      {required final String id,
      required final String subject,
      required final String senderName,
      required final String senderEmail,
      required final String snippet,
      required final String dateFormatted,
      required final bool isUnread}) = _$EmailPreviewImpl;

  @override
  String get id;
  @override
  String get subject;
  @override
  String get senderName;
  @override
  String get senderEmail;
  @override
  String get snippet;
  @override
  String get dateFormatted;
  @override
  bool get isUnread;
  @override
  @JsonKey(ignore: true)
  _$$EmailPreviewImplCopyWith<_$EmailPreviewImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

EmailLabel _$EmailLabelFromJson(Map<String, dynamic> json) {
  return _EmailLabel.fromJson(json);
}

/// @nodoc
mixin _$EmailLabel {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get type => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $EmailLabelCopyWith<EmailLabel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EmailLabelCopyWith<$Res> {
  factory $EmailLabelCopyWith(
          EmailLabel value, $Res Function(EmailLabel) then) =
      _$EmailLabelCopyWithImpl<$Res, EmailLabel>;
  @useResult
  $Res call({String id, String name, String type});
}

/// @nodoc
class _$EmailLabelCopyWithImpl<$Res, $Val extends EmailLabel>
    implements $EmailLabelCopyWith<$Res> {
  _$EmailLabelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? type = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$EmailLabelImplCopyWith<$Res>
    implements $EmailLabelCopyWith<$Res> {
  factory _$$EmailLabelImplCopyWith(
          _$EmailLabelImpl value, $Res Function(_$EmailLabelImpl) then) =
      __$$EmailLabelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, String name, String type});
}

/// @nodoc
class __$$EmailLabelImplCopyWithImpl<$Res>
    extends _$EmailLabelCopyWithImpl<$Res, _$EmailLabelImpl>
    implements _$$EmailLabelImplCopyWith<$Res> {
  __$$EmailLabelImplCopyWithImpl(
      _$EmailLabelImpl _value, $Res Function(_$EmailLabelImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? type = null,
  }) {
    return _then(_$EmailLabelImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$EmailLabelImpl implements _EmailLabel {
  const _$EmailLabelImpl(
      {required this.id, required this.name, this.type = 'user'});

  factory _$EmailLabelImpl.fromJson(Map<String, dynamic> json) =>
      _$$EmailLabelImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  @JsonKey()
  final String type;

  @override
  String toString() {
    return 'EmailLabel(id: $id, name: $name, type: $type)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EmailLabelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.type, type) || other.type == type));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, id, name, type);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$EmailLabelImplCopyWith<_$EmailLabelImpl> get copyWith =>
      __$$EmailLabelImplCopyWithImpl<_$EmailLabelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$EmailLabelImplToJson(
      this,
    );
  }
}

abstract class _EmailLabel implements EmailLabel {
  const factory _EmailLabel(
      {required final String id,
      required final String name,
      final String type}) = _$EmailLabelImpl;

  factory _EmailLabel.fromJson(Map<String, dynamic> json) =
      _$EmailLabelImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String get type;
  @override
  @JsonKey(ignore: true)
  _$$EmailLabelImplCopyWith<_$EmailLabelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

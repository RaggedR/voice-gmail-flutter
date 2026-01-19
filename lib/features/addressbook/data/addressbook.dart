import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:path_provider/path_provider.dart';

part 'addressbook.freezed.dart';
part 'addressbook.g.dart';

/// A contact in the addressbook
@freezed
class Contact with _$Contact {
  const factory Contact({
    required String name,
    required String email,
  }) = _Contact;

  factory Contact.fromJson(Map<String, dynamic> json) => _$ContactFromJson(json);
}

/// Simple JSON-based addressbook
class AddressBook {
  final Map<String, Contact> _contacts = {};
  String? _path;
  bool _loaded = false;

  /// Load contacts from storage
  Future<void> load() async {
    if (_loaded) return;

    try {
      final dir = await getApplicationDocumentsDirectory();
      _path = '${dir.path}/voice_gmail_contacts.json';
      final file = File(_path!);

      if (await file.exists()) {
        final contents = await file.readAsString();
        final data = jsonDecode(contents) as Map<String, dynamic>;
        for (final entry in data.entries) {
          _contacts[entry.key.toLowerCase()] = Contact(
            name: entry.key,
            email: entry.value as String,
          );
        }
      }
      _loaded = true;
    } catch (e) {
      debugPrint('Error loading addressbook: $e');
      _loaded = true;
    }
  }

  /// Save contacts to storage
  Future<void> _save() async {
    if (_path == null) return;

    try {
      final data = <String, String>{};
      for (final contact in _contacts.values) {
        data[contact.name] = contact.email;
      }
      final file = File(_path!);
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint('Error saving addressbook: $e');
    }
  }

  /// Add or update a contact
  Future<Contact> add(String name, String email) async {
    await load();
    final contact = Contact(name: name, email: email);
    _contacts[name.toLowerCase()] = contact;
    await _save();
    return contact;
  }

  /// Remove a contact by name
  Future<bool> remove(String name) async {
    await load();
    final key = name.toLowerCase();
    if (_contacts.containsKey(key)) {
      _contacts.remove(key);
      await _save();
      return true;
    }
    return false;
  }

  /// Get a contact by name (case-insensitive)
  Future<Contact?> get(String name) async {
    await load();
    return _contacts[name.toLowerCase()];
  }

  /// Search contacts by partial name match
  Future<List<Contact>> search(String query) async {
    await load();
    final queryLower = query.toLowerCase();
    return _contacts.values
        .where((c) => c.name.toLowerCase().contains(queryLower))
        .toList();
  }

  /// List all contacts
  Future<List<Contact>> listAll() async {
    await load();
    return _contacts.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  /// Resolve a name to email address, or return as-is if it's an email
  Future<String?> resolveEmail(String nameOrEmail) async {
    // If it looks like an email, return it
    if (nameOrEmail.contains('@')) {
      return nameOrEmail;
    }

    await load();

    // Try to find contact by exact name
    final contact = await get(nameOrEmail);
    if (contact != null) {
      return contact.email;
    }

    // Try partial match
    final matches = await search(nameOrEmail);
    if (matches.length == 1) {
      return matches.first.email;
    }

    return null;
  }
}

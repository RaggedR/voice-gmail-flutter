import 'dart:convert';
import 'dart:io';

import 'package:dart_phonetics/dart_phonetics.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';
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

/// Simple JSON-based addressbook with phonetic matching support
class AddressBook {
  final Map<String, Contact> _contacts = {};
  String? _path;
  bool _loaded = false;

  /// Double Metaphone encoder for phonetic matching of names
  final _metaphone = DoubleMetaphone.withMaxLength(10);

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

  /// Search contacts by partial name match, with phonetic and fuzzy matching fallback
  Future<List<Contact>> search(String query, {int fuzzyCutoff = 70}) async {
    await load();
    final queryLower = query.toLowerCase();

    // First try exact substring match
    var matches = _contacts.values
        .where((c) => c.name.toLowerCase().contains(queryLower))
        .toList();

    // If no exact matches, try phonetic matching
    if (matches.isEmpty && _contacts.isNotEmpty) {
      final phoneticMatches = await phoneticSearch(query);
      if (phoneticMatches.isNotEmpty) {
        return phoneticMatches;
      }
    }

    // If still no matches, try fuzzy matching
    if (matches.isEmpty && _contacts.isNotEmpty) {
      matches = _contacts.values.where((c) {
        final score = ratio(queryLower, c.name.toLowerCase());
        return score >= fuzzyCutoff;
      }).toList();

      // Sort by fuzzy match score (best first)
      matches.sort((a, b) {
        final scoreA = ratio(queryLower, a.name.toLowerCase());
        final scoreB = ratio(queryLower, b.name.toLowerCase());
        return scoreB.compareTo(scoreA);
      });
    }

    return matches;
  }

  /// Search contacts using phonetic matching (Double Metaphone)
  /// Matches names that sound similar: "jon" -> "John", "sara" -> "Sarah"
  Future<List<Contact>> phoneticSearch(String query) async {
    await load();
    if (_contacts.isEmpty) return [];

    final queryEnc = _metaphone.encode(query);
    if (queryEnc == null) return [];

    final matches = <Contact>[];

    for (final contact in _contacts.values) {
      // Get first name for comparison (most common case for voice commands)
      final firstName = contact.name.split(' ').first;
      final nameEnc = _metaphone.encode(firstName);
      if (nameEnc == null) continue;

      // Check if phonetic codes match (primary or alternates)
      if (queryEnc.primary == nameEnc.primary ||
          (nameEnc.alternates?.contains(queryEnc.primary) ?? false) ||
          (queryEnc.alternates?.any((alt) => alt == nameEnc.primary) ?? false)) {
        matches.add(contact);
      }
    }

    return matches;
  }

  /// Fuzzy search contacts - returns best matches above threshold
  Future<List<(Contact, int)>> fuzzySearch(String query, {int cutoff = 60, int limit = 5}) async {
    await load();
    if (_contacts.isEmpty) return [];

    final queryLower = query.toLowerCase();
    final results = <(Contact, int)>[];

    for (final contact in _contacts.values) {
      final score = ratio(queryLower, contact.name.toLowerCase());
      if (score >= cutoff) {
        results.add((contact, score));
      }
    }

    // Sort by score descending
    results.sort((a, b) => b.$2.compareTo(a.$2));

    return results.take(limit).toList();
  }

  /// List all contacts
  Future<List<Contact>> listAll() async {
    await load();
    return _contacts.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  /// Resolve a name to email address, or return as-is if it's an email
  /// Uses phonetic and fuzzy matching as fallback when exact/substring match fails
  Future<String?> resolveEmail(String nameOrEmail, {int fuzzyCutoff = 70}) async {
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

    // Try phonetic match first (best for voice-to-text errors)
    final phoneticMatches = await phoneticSearch(nameOrEmail);
    if (phoneticMatches.length == 1) {
      debugPrint('[AddressBook] Phonetic matched "$nameOrEmail" -> "${phoneticMatches.first.name}"');
      return phoneticMatches.first.email;
    }

    // Try partial/fuzzy match (search now includes fuzzy matching)
    final matches = await search(nameOrEmail, fuzzyCutoff: fuzzyCutoff);
    if (matches.length == 1) {
      return matches.first.email;
    }

    // If still no matches, try fuzzy search with lower threshold
    if (matches.isEmpty && _contacts.isNotEmpty) {
      final fuzzyMatches = await fuzzySearch(nameOrEmail, cutoff: fuzzyCutoff, limit: 1);
      if (fuzzyMatches.isNotEmpty) {
        final (bestMatch, score) = fuzzyMatches.first;
        debugPrint('[AddressBook] Fuzzy matched "$nameOrEmail" -> "${bestMatch.name}" (score: $score)');
        return bestMatch.email;
      }
    }

    // If multiple phonetic matches, return first (user said a common name)
    if (phoneticMatches.isNotEmpty) {
      debugPrint('[AddressBook] Multiple phonetic matches for "$nameOrEmail", using first: "${phoneticMatches.first.name}"');
      return phoneticMatches.first.email;
    }

    return null;
  }
}

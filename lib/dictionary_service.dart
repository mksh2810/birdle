/// Service for fetching word definitions from the Free Dictionary API.
///
/// Uses https://api.dictionaryapi.dev (free, no API key required).
/// Falls back to a local hint when the API is unavailable.
library;

import 'dart:convert';
import 'package:http/http.dart' as http;

/// Holds a word's definition, example sentence, and part of speech.
class WordDefinition {
  const WordDefinition({
    required this.definition,
    this.example,
    this.partOfSpeech,
  });

  /// The meaning of the word.
  final String definition;

  /// An example sentence using the word (may be null).
  final String? example;

  /// The part of speech (noun, verb, adjective, etc.).
  final String? partOfSpeech;

  /// Creates a fallback definition when the API is unavailable.
  factory WordDefinition.fallback(String word) {
    return WordDefinition(
      definition: 'A 5-letter English word starting with "${word[0].toUpperCase()}".',
      example: null,
      partOfSpeech: null,
    );
  }
}

/// Fetches definitions from the Free Dictionary API.
class DictionaryService {
  static const String _baseUrl =
      'https://api.dictionaryapi.dev/api/v2/entries/en';

  /// Fetches the definition and example for [word].
  ///
  /// Returns a [WordDefinition] with the first available definition
  /// and example sentence. If the API call fails or the word is not found,
  /// returns a fallback hint instead.
  static Future<WordDefinition> fetchDefinition(String word) async {
    try {
      final uri = Uri.parse('$_baseUrl/$word');
      final response = await http.get(uri).timeout(
        const Duration(seconds: 8),
      );

      if (response.statusCode != 200) {
        return WordDefinition.fallback(word);
      }

      final List<dynamic> data = jsonDecode(response.body);
      if (data.isEmpty) return WordDefinition.fallback(word);

      final entry = data[0] as Map<String, dynamic>;
      final meanings = entry['meanings'] as List<dynamic>?;
      if (meanings == null || meanings.isEmpty) {
        return WordDefinition.fallback(word);
      }

      // Search all meanings for the best definition + example pair.
      String? bestDefinition;
      String? bestExample;
      String? bestPartOfSpeech;

      for (final meaning in meanings) {
        final partOfSpeech = meaning['partOfSpeech'] as String?;
        final definitions = meaning['definitions'] as List<dynamic>?;
        if (definitions == null || definitions.isEmpty) continue;

        for (final def in definitions) {
          final definition = def['definition'] as String?;
          final example = def['example'] as String?;

          if (definition != null && definition.isNotEmpty) {
            // Prefer definitions that come with examples.
            if (bestDefinition == null || (bestExample == null && example != null)) {
              bestDefinition = _sanitizeDefinition(definition, word);
              bestExample = example != null ? _sanitizeExample(example, word) : null;
              bestPartOfSpeech = partOfSpeech;
            }
            // If we already have a definition with an example, stop.
            if (bestExample != null) break;
          }
        }
        if (bestExample != null) break;
      }

      if (bestDefinition == null) return WordDefinition.fallback(word);

      return WordDefinition(
        definition: bestDefinition,
        example: bestExample,
        partOfSpeech: bestPartOfSpeech,
      );
    } catch (_) {
      return WordDefinition.fallback(word);
    }
  }

  /// Removes the word itself from the definition text to avoid
  /// giving the answer away, replacing it with blanks.
  static String _sanitizeDefinition(String text, String word) {
    final pattern = RegExp(word, caseSensitive: false);
    return text.replaceAll(pattern, '_____');
  }

  /// Removes the word from the example sentence,
  /// replacing it with blanks.
  static String _sanitizeExample(String text, String word) {
    final pattern = RegExp(word, caseSensitive: false);
    return text.replaceAll(pattern, '_____');
  }
}

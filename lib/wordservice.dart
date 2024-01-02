import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:english_app/word.dart';

class WordService {
  Future<String> _loadJsonFromAsset() async {
    return rootBundle.loadString('assets/dictionary.json');
  }

  Future<String> getDefinition(String word) async {
    final jsonString = await _loadJsonFromAsset();
    final jsonData = jsonDecode(jsonString);
    if (jsonData.containsKey(word)) {
      return jsonData[word];
    } else {
      throw Exception('Word not found');
    }
  }

  Future<List<Word>> getWords() async { // Modified method name from _getWords to getWords
    final jsonString = await _loadJsonFromAsset();
    final jsonData = jsonDecode(jsonString);

    List<Word> words = [];

    jsonData.forEach((word, definition) {
      words.add(Word(word: word, meaning: definition));
    });

    return words;
  }

}
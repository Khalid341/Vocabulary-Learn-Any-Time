import 'package:flutter/material.dart';

class WordPage extends StatelessWidget {
  final String word;
  final String meaning;

  const WordPage({super.key, required this.word, required this.meaning});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textSelectionTheme: const TextSelectionThemeData(
          selectionColor: Colors.black,
          cursorColor: Colors.black,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Word of the Day'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              SelectableText(
                'Word: $word',
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(height: 16),
              SelectableText(
                'Meaning: $meaning',
                style: const TextStyle(fontSize: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

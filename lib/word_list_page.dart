import 'package:english_app/word.dart';
import 'package:flutter/material.dart';

class WordsListPage extends StatefulWidget {
  final List<Word> words;

  const WordsListPage({super.key, required this.words});

  @override
  _WordsListPageState createState() => _WordsListPageState();
}

class _WordsListPageState extends State<WordsListPage> {
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
          title: const Text('Your Words'),
        ),
        body: ListView.builder(
          itemCount: widget.words.length,
          itemBuilder: (context, index) {
            return ListTile(
              title: SelectableText(widget.words[index].word),
              subtitle: SelectableText(widget.words[index].meaning),
            );
          },
        ),
      ),
    );
  }
}

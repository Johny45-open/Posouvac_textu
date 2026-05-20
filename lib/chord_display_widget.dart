import 'package:flutter/material.dart';
import 'chord_pro_parser.dart';

class ChordDisplayWidget extends StatelessWidget {
  final String content;
  final TextStyle textStyle;
  final TextStyle chordStyle;

  const ChordDisplayWidget({
    Key? key,
    required this.content,
    this.textStyle = const TextStyle(fontSize: 18, color: Colors.black),
    this.chordStyle = const TextStyle(
        fontSize: 16, color: Colors.blue, fontWeight: FontWeight.bold),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final lines = ChordProParser.parse(content);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) => _buildLine(line)).toList(),
    );
  }

  Widget _buildLine(LyricLine line) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Wrap(
        children: line.elements.map((element) {
          if (element.chord != null) {
            return Padding(
              padding: const EdgeInsets.only(right: 4.0),
              child: Text(element.chord!, style: chordStyle),
            );
          }
          return Text(element.text, style: textStyle);
        }).toList(),
      ),
    );
  }
}

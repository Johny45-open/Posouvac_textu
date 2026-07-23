import 'package:flutter/material.dart';
import 'chord_pro_parser.dart';

class ChordDisplayWidget extends StatelessWidget {
  final String content;
  final TextStyle textStyle;
  final TextStyle chordStyle;
  final TextStyle commentStyle;

  const ChordDisplayWidget({
    Key? key,
    required this.content,
    this.textStyle = const TextStyle(fontSize: 18, color: Colors.black),
    this.chordStyle = const TextStyle(
        fontSize: 16, color: Colors.blue, fontWeight: FontWeight.bold),
    this.commentStyle = const TextStyle(
        fontSize: 14, color: Colors.grey, fontStyle: FontStyle.italic),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final sections = ChordProParser.parse(content);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections.map((section) => _buildSection(section)).toList(),
    );
  }

  Widget _buildSection(ChordProSection section) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: section.title != null ? const EdgeInsets.all(8.0) : EdgeInsets.zero,
      decoration: section.title != null
          ? BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8))
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (section.title != null)
            Semantics(
              header: true,
              child: Text(section.title!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ...section.lines.map((line) => _buildLine(line)),
        ],
      ),
    );
  }

  Widget _buildLine(List<ChordProElement> line) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Wrap(
        children: line.map((element) {
          if (element.type == ElementType.chord) {
            return Padding(
              padding: const EdgeInsets.only(right: 4.0),
              child: Semantics(
                label: "Akord: ${element.content}",
                child: Text(element.content, style: chordStyle),
              ),
            );
          } else if (element.type == ElementType.comment) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Semantics(
                label: "Komentář: ${element.content}",
                child: Text(element.content, style: commentStyle),
              ),
            );
          } else if (element.type == ElementType.stopMark) {
            final bars = element.stopMarkBars ?? 0;
            return Semantics(
              label: "Pauza, ${bars > 0 ? '$bars takty' : 'manuální'}",
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.0),
                child: Icon(Icons.pause_circle_outline, size: 20, color: Colors.red),
              ),
            );
          }
          return Text(element.content, style: textStyle);
        }).toList(),
      ),
    );
  }
}

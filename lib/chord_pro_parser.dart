class LyricElement {
  final String text;
  final String? chord;

  LyricElement(this.text, {this.chord});

  @override
  String toString() => chord != null ? '[$chord]$text' : text;
}

class LyricLine {
  final List<LyricElement> elements;

  LyricLine(this.elements);
}

class ChordProParser {
  // Regex pro vyhledání akordů v hranatých závorkách
  static final RegExp _chordRegex = RegExp(r'\[([^\]]*)\]');

  static List<LyricLine> parse(String content) {
    final lines = content.split('\n');
    return lines.map((line) {
      final elements = <LyricElement>[];
      int lastIndex = 0;

      final matches = _chordRegex.allMatches(line);

      for (final match in matches) {
        // Text před akordem
        final textBefore = line.substring(lastIndex, match.start);
        if (textBefore.isNotEmpty) {
          elements.add(LyricElement(textBefore));
        }

        // Akord
        final chord = match.group(1);
        elements.add(LyricElement('', chord: chord));

        lastIndex = match.end;
      }

      // Zbývající text
      final textAfter = line.substring(lastIndex);
      if (textAfter.isNotEmpty) {
        elements.add(LyricElement(textAfter));
      }

      return LyricLine(elements);
    }).toList();
  }
}

enum ElementType { text, chord, comment, stopMark }

class ChordProElement {
  final ElementType type;
  final String content;
  final int? stopMarkBars; // Pro stopMark

  ChordProElement(this.type, this.content, {this.stopMarkBars});
}

class ChordProSection {
  final String? title;
  final List<List<ChordProElement>> lines;

  ChordProSection(this.lines, {this.title});
}

class ChordProParser {
  static List<ChordProSection> parse(String content) {
    final lines = content.split('\n');
    final sections = <ChordProSection>[];
    List<List<ChordProElement>> currentLines = [];
    String? currentSectionTitle;

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      // Parsování direktiv {directive}
      if (line.startsWith('{') && line.endsWith('}')) {
        final directive = line.substring(1, line.length - 1);
        if (directive.startsWith('soc') || directive.startsWith('chorus')) {
          currentSectionTitle = "Refrén";
        } else if (directive.startsWith('eoc')) {
          sections.add(ChordProSection(currentLines, title: currentSectionTitle));
          currentLines = [];
          currentSectionTitle = null;
        } else if (directive.startsWith('c:')) {
          currentLines.add([ChordProElement(ElementType.comment, directive.substring(2))]);
        } else if (directive.startsWith('stop:') || directive.startsWith('pause:')) {
          final parts = directive.split(':');
          final bars = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
          currentLines.add([ChordProElement(ElementType.stopMark, "Pauza", stopMarkBars: bars)]);
        }
        continue;
      }

      // Parsování řádku s akordy [chord] a textem
      currentLines.add(_parseLine(line));
    }

    if (currentLines.isNotEmpty) {
      sections.add(ChordProSection(currentLines, title: currentSectionTitle));
    }

    return sections;
  }

  static List<ChordProElement> _parseLine(String line) {
    final elements = <ChordProElement>[];
    final regex = RegExp(r'\[([^\]]*)\]|([^[\]]+)');
    final matches = regex.allMatches(line);

    for (final match in matches) {
      if (match.group(1) != null) {
        elements.add(ChordProElement(ElementType.chord, match.group(1)!));
      } else if (match.group(2) != null) {
        elements.add(ChordProElement(ElementType.text, match.group(2)!));
      }
    }
    return elements;
  }

  // Všechny logické řádky v pořadí, v jakém se vykreslují (přes sekce).
  static List<List<ChordProElement>> orderedLines(String content) =>
      parse(content).expand((section) => section.lines).toList();

  // Spojený text řádku (bez direktiv), vhodný jako stabilní kotva.
  static String lineText(List<ChordProElement> line) =>
      line.map((e) => e.content).join('').trim();

  // Indexy řádků obsahujících direktivu zarážky ({stop:N} / {pause:N})
  // spolu s délkou pauzy v taktech.
  static List<({int index, int bars})> stopMarksInLines(String content) {
    final marks = <({int index, int bars})>[];
    final lines = orderedLines(content);
    for (var i = 0; i < lines.length; i++) {
      for (final e in lines[i]) {
        if (e.type == ElementType.stopMark) {
          marks.add((index: i, bars: e.stopMarkBars ?? 0));
        }
      }
    }
    return marks;
  }
}

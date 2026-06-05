class ChordTransposer {
  static const List<String> _sharpKeys = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
  static const List<String> _flatKeys = ['C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B'];

  static String transposeChord(String chord, int semitones) {
    if (semitones == 0) return chord;

    // Najdeme základní tón (např. "C#" z "C#min7")
    final match = RegExp(r'^([A-G][b#]?)').firstMatch(chord);
    if (match == null) return chord;

    String root = match.group(1)!;
    String suffix = chord.substring(root.length);

    int index = _sharpKeys.indexOf(root);
    if (index == -1) index = _flatKeys.indexOf(root);
    if (index == -1) return chord;

    int newIndex = (index + semitones) % 12;
    if (newIndex < 0) newIndex += 12;

    // Rozhodneme se, zda použít křížky nebo béčka (zjednodušeně podle původního akordu)
    bool useFlats = root.contains('b') || (root == 'F' && semitones < 0);
    String newRoot = useFlats ? _flatKeys[newIndex] : _sharpKeys[newIndex];

    return newRoot + suffix;
  }

  static String transposeText(String content, int semitones) {
    if (semitones == 0) return content;
    
    // Hledáme akordy v hranatých závorkách [C#min7]
    return content.replaceAllMapped(RegExp(r'\[([^\]]+)\]'), (match) {
      String chord = match.group(1)!;
      // Pokud je v závorkách víc akordů oddělených mezerou/lomítkem
      final parts = chord.split(RegExp(r'([ /])'));
      String result = "";
      int lastEnd = 0;
      
      final allMatches = RegExp(r'([ /])').allMatches(chord);
      int partIdx = 0;
      
      // Opravená verze splitMapJoin pro vnitřek závorek
      String innerTransposed = chord.splitMapJoin(
        RegExp(r'([A-G][b#]?[^ /]*)'),
        onMatch: (m) => transposeChord(m.group(0)!, semitones),
        onNonMatch: (s) => s,
      );

      return '[$innerTransposed]';
    });
  }
}

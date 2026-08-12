import 'package:flutter/material.dart';
import 'chord_pro_parser.dart';

class ChordDisplayWidget extends StatefulWidget {
  final String content;
  final TextStyle textStyle;
  final TextStyle chordStyle;
  final TextStyle commentStyle;
  final Set<int>? anchorLines;
  final ValueChanged<Map<int, double>>? onLineOffsetsChanged;

  const ChordDisplayWidget({
    super.key,
    required this.content,
    this.textStyle = const TextStyle(fontSize: 18, color: Colors.black),
    this.chordStyle = const TextStyle(
        fontSize: 16, color: Colors.blue, fontWeight: FontWeight.bold),
    this.commentStyle = const TextStyle(
        fontSize: 14, color: Colors.grey, fontStyle: FontStyle.italic),
    this.anchorLines,
    this.onLineOffsetsChanged,
  });

  @override
  State<ChordDisplayWidget> createState() => ChordDisplayWidgetState();
}

class ChordDisplayWidgetState extends State<ChordDisplayWidget> {
  final GlobalKey _contentKey = GlobalKey();
  final List<GlobalKey> _lineKeys = [];

  @override
  Widget build(BuildContext context) {
    final sections = ChordProParser.parse(widget.content);

    _lineKeys
      ..clear()
      ..addAll(sections.expand((s) => s.lines).map((_) => GlobalKey()));

    WidgetsBinding.instance.addPostFrameCallback((_) => _measureLineOffsets());

    int lineCounter = 0;
    return Column(
      key: _contentKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final section in sections) _buildSection(section, () => lineCounter++),
      ],
    );
  }

  void _measureLineOffsets() {
    if (!mounted) return;
    final contentBox = _contentKey.currentContext?.findRenderObject() as RenderBox?;
    if (contentBox == null) return;
    final contentTop = contentBox.localToGlobal(Offset.zero).dy;

    final offsets = <int, double>{};
    for (var i = 0; i < _lineKeys.length; i++) {
      final box = _lineKeys[i].currentContext?.findRenderObject() as RenderBox?;
      if (box == null) continue;
      offsets[i] = box.localToGlobal(Offset.zero).dy - contentTop;
    }
    widget.onLineOffsetsChanged?.call(offsets);
  }

  Widget _buildSection(ChordProSection section, int Function() nextIndex) {
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
          for (final line in section.lines) _buildLine(nextIndex(), line),
        ],
      ),
    );
  }

  Widget _buildLine(int index, List<ChordProElement> line) {
    final isAnchor = widget.anchorLines?.contains(index) ?? false;
    return Padding(
      key: _lineKeys[index],
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (isAnchor)
            Padding(
              padding: const EdgeInsets.only(right: 4.0),
              child: Semantics(
                label: "Zarážka",
                child: const Icon(Icons.pause_circle_filled, size: 20, color: Colors.red),
              ),
            ),
          ...line.map(_buildElement),
        ],
      ),
    );
  }

  Widget _buildElement(ChordProElement element) {
    if (element.type == ElementType.chord) {
      return Padding(
        padding: const EdgeInsets.only(right: 4.0),
        child: Semantics(
          label: "Akord: ${element.content}",
          child: Text(element.content, style: widget.chordStyle),
        ),
      );
    }
    if (element.type == ElementType.comment) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Semantics(
          label: "Komentář: ${element.content}",
          child: Text(element.content, style: widget.commentStyle),
        ),
      );
    }
    if (element.type == ElementType.stopMark) {
      final bars = element.stopMarkBars ?? 0;
      return Semantics(
        label: "Pauza, ${bars > 0 ? '$bars takty' : 'manuální'}",
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.0),
          child: Icon(Icons.pause_circle_outline, size: 20, color: Colors.red),
        ),
      );
    }
    return Text(element.content, style: widget.textStyle);
  }
}
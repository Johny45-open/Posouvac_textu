/// Normalizace textu pro vyhledávání – sdílená mezi knihovnou, setlist syncem a diakritikou.
/// Založeno na `database.dart:_stripDiacritics/_normForMatch` – extrahováno jako public API.
class TextNormalizer {
  static const Map<String, String> _map = {
    'á': 'a', 'č': 'c', 'ď': 'd', 'é': 'e', 'ě': 'e', 'í': 'i', 'ň': 'n',
    'ó': 'o', 'ř': 'r', 'š': 's', 'ť': 't', 'ú': 'u', 'ů': 'u', 'ý': 'y', 'ž': 'z',
    'Á': 'A', 'Č': 'C', 'Ď': 'D', 'É': 'E', 'Ě': 'E', 'Í': 'I', 'Ň': 'N',
    'Ó': 'O', 'Ř': 'R', 'Š': 'S', 'Ť': 'T', 'Ú': 'U', 'Ů': 'U', 'Ý': 'Y', 'Ž': 'Z',
    'ä': 'a', 'ë': 'e', 'ï': 'i', 'ö': 'o', 'ü': 'u',
    'Ä': 'A', 'Ë': 'E', 'Ï': 'I', 'Ö': 'O', 'Ü': 'U',
    'à': 'a', 'è': 'e', 'ì': 'i', 'ò': 'o', 'ù': 'u',
    'À': 'A', 'È': 'E', 'Ì': 'I', 'Ò': 'O', 'Ù': 'U',
    'â': 'a', 'ê': 'e', 'î': 'i', 'ô': 'o', 'û': 'u',
    'Â': 'A', 'Ê': 'E', 'Î': 'I', 'Ô': 'O', 'Û': 'U',
  };

  static String stripDiacritics(String input) {
    var out = input;
    _map.forEach((k, v) => out = out.replaceAll(k, v));
    return out;
  }

  /// Normalizace pro porovnání: strip diakritiky + lowercase + sjednocení mezer.
  static String normForSearch(String input) =>
      stripDiacritics(input.trim().toLowerCase()).replaceAll(RegExp(r'\s+'), ' ');

  /// Jen diakritika – použito pro validaci „pouze diakritika“ (odmítá překlepy).
  static bool isDiacriticOnly(String raw, String corrected) =>
      normForSearch(raw) == normForSearch(corrected);
}

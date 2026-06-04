import 'package:drift/drift.dart';

@DataClassName('SongEntry')
class Songs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get filePath => text().unique()();
  TextColumn get artist => text()();
  TextColumn get title => text()();
  RealColumn get tempo => real().nullable()();
  RealColumn get introDuration => real().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  BoolColumn get isPlayed => boolean().withDefault(const Constant(false))();
  RealColumn get customFontSize => real().nullable()();
  RealColumn get customScrollSpeed => real().nullable()();
}

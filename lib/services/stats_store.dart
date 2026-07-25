import 'package:shared_preferences/shared_preferences.dart';
import '../models/stats.dart';

/// Loads and saves the aggregate [StatsBook] to on-device storage.
class StatsStore {
  static const _key = 'speedbee.stats.v1';
  final SharedPreferences prefs;
  StatsBook book;

  StatsStore._(this.prefs, this.book);

  static Future<StatsStore> load(SharedPreferences prefs) async {
    final raw = prefs.getString(_key);
    final book = raw == null ? StatsBook.empty() : StatsBook.decode(raw);
    return StatsStore._(prefs, book);
  }

  Future<void> save() => prefs.setString(_key, book.encode());

  SizeStats forSize(int size) => book.bySize[size]!;

  Future<void> recordStarted(int size) async {
    forSize(size).gamesStarted++;
    await save();
  }

  Future<void> recordPangram(int size, int ms) async {
    forSize(size).addPangram(ms);
    await save();
  }

  Future<void> recordPerfect(int size, int ms) async {
    forSize(size).addPerfect(ms);
    await save();
  }

  Future<void> recordComplete(int size, int ms) async {
    forSize(size).addComplete(ms);
    await save();
  }

  /// Fold a finished game's oops rate into the aggregate (once per game).
  Future<void> recordEnd(int size, int oops, int attempts) async {
    forSize(size).addEnd(oops, attempts);
    await save();
  }

  Future<void> reset() async {
    book = StatsBook.empty();
    await save();
  }
}

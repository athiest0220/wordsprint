import 'package:http/http.dart' as http;

/// A fetched Spelling Bee puzzle definition.
class FetchedBee {
  final String center; // uppercase
  final List<String> letters; // 7 uppercase, includes center
  const FetchedBee(this.center, this.letters);
}

/// Fetches today's NYT Spelling Bee letters from sbsolver.com.
///
/// The page marks the center as `alt="center letter K"` and encodes all seven
/// letters in a link slug like `/s/kEginov`. We read both and cross-check.
class NytFetcher {
  static const _url = 'https://www.sbsolver.com/answers';
  static const _ua =
      'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/120.0 Mobile Safari/537.36';

  static Future<FetchedBee> fetchToday() async {
    final resp = await http
        .get(Uri.parse(_url), headers: {'User-Agent': _ua})
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception('Site returned ${resp.statusCode}');
    }
    final html = resp.body;

    final center = RegExp(r'alt="center letter ([A-Za-z])"')
        .firstMatch(html)
        ?.group(1)
        ?.toUpperCase();
    final slug =
        RegExp(r'/s/([a-zA-Z]{7})"').firstMatch(html)?.group(1);

    if (center == null || slug == null) {
      throw Exception('Could not read the letters from the page');
    }
    final letters = slug.toUpperCase().split('').toSet().toList();
    if (letters.length != 7 || !letters.contains(center)) {
      throw Exception('Unexpected letters ($slug / center $center)');
    }
    return FetchedBee(center, letters);
  }
}

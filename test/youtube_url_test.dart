import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_downloader/services/youtube_url.dart';

void main() {
  group('extractVideoId', () {
    test('parses the example link with playlist params', () {
      expect(
        extractVideoId(
            'https://www.youtube.com/watch?v=Jc10TXOh-yM&list=RDJc10TXOh-yM&start_radio=1'),
        'Jc10TXOh-yM',
      );
    });

    test('parses short and shared links', () {
      expect(extractVideoId('https://youtu.be/Jc10TXOh-yM?si=abc'),
          'Jc10TXOh-yM');
      expect(extractVideoId('https://m.youtube.com/watch?v=Jc10TXOh-yM'),
          'Jc10TXOh-yM');
    });

    test('finds the link inside share text', () {
      expect(
        extractVideoId('Look at this https://youtu.be/Jc10TXOh-yM now'),
        'Jc10TXOh-yM',
      );
    });

    test('returns null for invalid input', () {
      expect(extractVideoId(null), isNull);
      expect(extractVideoId(''), isNull);
      expect(extractVideoId('https://example.com/video'), isNull);
    });
  });

  group('sanitizeFileName', () {
    test('replaces forbidden characters', () {
      expect(sanitizeFileName('a/b:c*d?"e<f>g|h'), 'a_b_c_d__e_f_g_h');
    });
    test('falls back for empty and limits length', () {
      expect(sanitizeFileName('   '), 'video');
      expect(sanitizeFileName('x' * 300).length, 120);
    });
  });
}

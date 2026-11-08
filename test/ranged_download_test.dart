import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:youtube_downloader/services/youtube_source.dart';

void main() {
  test('rangedDownload fetches the file in ranged chunks', () async {
    final data = List<int>.generate(25, (i) => i);
    final ranges = <String>[];
    final client = MockClient((req) async {
      final range = req.headers['Range']!;
      ranges.add(range);
      final m = RegExp(r'bytes=(\d+)-(\d+)').firstMatch(range)!;
      final s = int.parse(m.group(1)!);
      final e = int.parse(m.group(2)!);
      return http.Response.bytes(data.sublist(s, e + 1), 206);
    });
    final bytes = <int>[];
    await for (final c in ExplodeYoutubeSource.rangedDownload(
        Uri.parse('https://x/y'), 25,
        chunk: 10, client: client)) {
      bytes.addAll(c);
    }
    expect(bytes, data);
    expect(ranges, ['bytes=0-9', 'bytes=10-19', 'bytes=20-24']);
  });

  test('rangedDownload fails on HTTP errors', () {
    final client = MockClient((_) async => http.Response('', 403));
    expect(
      ExplodeYoutubeSource.rangedDownload(Uri.parse('https://x/y'), 5,
              client: client)
          .toList(),
      throwsException,
    );
  });
}

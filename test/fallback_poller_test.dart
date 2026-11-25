import 'package:flutter_test/flutter_test.dart';
import 'package:ikiot_mobile/core/realtime/fallback_poller.dart';

// testWidgets chạy trong FakeAsync: tester.pump(duration) cho đồng hồ chạy mà không phải chờ thật.
void main() {
  const every = Duration(seconds: 20);

  FallbackPoller poller(List<int> ticks) =>
      FallbackPoller(onTick: () => ticks.add(1), interval: every);

  testWidgets('socket chưa nối được thì gọi lại theo chu kỳ', (tester) async {
    final ticks = <int>[];
    final p = poller(ticks)..start();
    await tester.pump(every * 3);
    expect(ticks.length, 3);
    p.stop();
  });

  testWidgets('chưa start thì không gọi gì', (tester) async {
    final ticks = <int>[];
    poller(ticks).disconnected();
    await tester.pump(every * 3);
    expect(ticks, isEmpty);
  });

  testWidgets('socket nối được thì dừng, rơi lại thì chạy tiếp', (
    tester,
  ) async {
    final ticks = <int>[];
    final p = poller(ticks)
      ..start()
      ..connected();
    await tester.pump(every * 3);
    expect(ticks, isEmpty);
    expect(p.isPolling, isFalse);

    p.disconnected();
    await tester.pump(every);
    expect(ticks.length, 1);
    p.stop();
  });

  testWidgets(
    'disconnected lặp lại (connect_error mỗi lần thử) không chồng timer',
    (tester) async {
      final ticks = <int>[];
      final p = poller(ticks)..start();
      for (var i = 0; i < 5; i++) {
        p.disconnected();
      }
      await tester.pump(every);
      expect(ticks.length, 1);
      p.stop();
    },
  );

  testWidgets('xuống nền thì dừng; quay lại mà vẫn rơi thì gọi ngay một nhịp', (
    tester,
  ) async {
    final ticks = <int>[];
    final p = poller(ticks)
      ..start()
      ..foreground(false);
    await tester.pump(every * 3);
    expect(ticks, isEmpty);

    p.foreground(true);
    expect(ticks.length, 1);
    await tester.pump(every);
    expect(ticks.length, 2);
    p.stop();
  });

  testWidgets('quay lại khi socket đang nối thì không gọi gì', (tester) async {
    final ticks = <int>[];
    final p = poller(ticks)
      ..start()
      ..connected()
      ..foreground(false)
      ..foreground(true);
    await tester.pump(every * 2);
    expect(ticks, isEmpty);
    p.stop();
  });

  testWidgets('stop (đăng xuất) thì dừng hẳn', (tester) async {
    final ticks = <int>[];
    final p = poller(ticks)..start();
    await tester.pump(every);
    p.stop();
    await tester.pump(every * 3);
    expect(ticks.length, 1);
  });
}

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_downloader/main.dart';
import 'package:youtube_downloader/services/app_settings.dart';
import 'package:youtube_downloader/services/download_service.dart';
import 'package:youtube_downloader/services/shared_text.dart';
import 'package:youtube_downloader/ui/app_state.dart';

class _DownloadService extends Mock implements DownloadService {}

class _SemanticsBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  ui.SemanticsUpdateBuilder createSemanticsUpdateBuilder() => _UpdateSpy();
}

class _Node {
  _Node(this.traversal, this.hitTest);
  final List<int> traversal;
  final List<int> hitTest;
}

class _UpdateSpy extends Fake implements ui.SemanticsUpdateBuilder {
  final ui.SemanticsUpdateBuilder _inner = ui.SemanticsUpdateBuilder();
  final Map<int, _Node> _updates = {};
  static final Map<int, _Node> _tree = {};
  static final List<int> orphanUpdates = [];
  static final Set<int> missingNodes = {};

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName != #updateNode) {
      return super.noSuchMethod(invocation);
    }
    final args = invocation.namedArguments;
    final id = args[#id] as int;
    _updates[id] = _Node(
      (args[#childrenInTraversalOrder] as Int32List).toList(),
      (args[#childrenInHitTestOrder] as Int32List).toList(),
    );
    return Function.apply(_inner.updateNode, const [], args);
  }

  @override
  void updateCustomAction({
    required int id,
    String? label,
    String? hint,
    int overrideId = -1,
  }) => _inner.updateCustomAction(
    id: id,
    label: label,
    hint: hint,
    overrideId: overrideId,
  );

  @override
  ui.SemanticsUpdate build() {
    _tree.addAll(_updates);
    Set<int> reachable({required bool hitTest}) {
      final visited = <int>{};
      void visit(int id) {
        if (!visited.add(id)) return;
        final node = _tree[id];
        if (node == null) {
          missingNodes.add(id);
          return;
        }
        for (final child in hitTest ? node.hitTest : node.traversal) {
          visit(child);
        }
      }

      visit(0);
      return visited;
    }

    final traversal = reachable(hitTest: false);
    final hitTest = reachable(hitTest: true);
    orphanUpdates.addAll(
      _updates.keys.where(
        (id) => !traversal.contains(id) || !hitTest.contains(id),
      ),
    );
    _tree.removeWhere(
      (id, _) => !traversal.contains(id) && !hitTest.contains(id),
    );
    return _inner.build();
  }
}

void main() {
  _SemanticsBinding();

  testWidgets('hidden slider keeps startup semantics connected', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final semantics = tester.ensureSemantics();
    try {
      final settings = AppSettings();
      final state = AppState(_DownloadService(), opener: (_) async {});
      await tester.pumpWidget(
        YoutubeDownloaderApp(
          state: state,
          settings: settings,
          sharedText: NoSharedTextSource(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('searchField')), findsOneWidget);
      expect(_UpdateSpy.orphanUpdates, isEmpty);
      expect(_UpdateSpy.missingNodes, isEmpty);

      await tester.tap(find.byKey(const Key('settingsButton')));
      await tester.pumpAndSettle();
      await settings.setTrimLeadingSilence(true);
      final slider = find.byKey(const Key('silenceThresholdDb'));
      await tester.ensureVisible(slider);
      await tester.pumpAndSettle();
      final owner = tester.binding.renderViews.first.owner!.semanticsOwner!;
      final sliders = <SemanticsNode>[];
      void collect(SemanticsNode node) {
        if (node.getSemanticsData().flagsCollection.isSlider) {
          sliders.add(node);
        }
        node.visitChildren((child) {
          collect(child);
          return true;
        });
      }

      collect(owner.rootSemanticsNode!);
      expect(sliders, hasLength(1));
      final data = sliders.single.getSemanticsData();
      expect(data.hasAction(SemanticsAction.increase), isTrue);
      expect(data.hasAction(SemanticsAction.decrease), isTrue);
      final initialValue = settings.silenceThresholdDb;
      owner.performAction(sliders.single.id, SemanticsAction.increase);
      await tester.pumpAndSettle();
      expect(settings.silenceThresholdDb, greaterThan(initialValue));
      expect(_UpdateSpy.orphanUpdates, isEmpty);
      expect(_UpdateSpy.missingNodes, isEmpty);
    } finally {
      semantics.dispose();
    }
  });
}

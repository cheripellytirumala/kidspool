import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidspool/common/core/di/injection_container.dart';
import 'package:kidspool/common/core/error/exceptions.dart';
import 'package:kidspool/common/core/network/api_client.dart';
import 'package:kidspool/feedback/feedback_repository.dart';
import 'package:kidspool/common/core/services/photo_picker.dart';
import 'package:kidspool/common/core/router/app_router.dart';
import 'package:kidspool/feedback/feedback_screen.dart';

class _FakePicker extends PhotoPicker {
  _FakePicker(this.path);
  final String path;

  @override
  Future<String?> pick({
    required bool fromCamera,
    bool frontCamera = false,
  }) async => path;
}

Future<String> _tempImage(String name) async {
  final dir = await Directory.systemTemp.createTemp('fb');
  final f = File('${dir.path}/$name')..writeAsBytesSync(List.filled(64, 1));
  return f.path;
}

class _FakeApi extends ApiClient {
  _FakeApi() : super(Dio());

  final calls = <(String, Map<String, dynamic>?)>[];
  final functions = <String>[];
  final uploads = <FormData>[];
  ServerException? error;
  bool uploadFails = false;

  @override
  Future<T> invokeFunction<T>(
    String name, {
    required ResponseParser<T> parser,
    Object? data,
    bool skipAuth = false,
  }) async {
    functions.add(name);
    if (data is FormData) {
      uploads.add(data);
      if (uploadFails) throw const ServerException('Too big', 400);
    }
    return parser({'sent': 1});
  }

  @override
  Future<T> rpc<T>(
    String name, {
    required ResponseParser<T> parser,
    Map<String, dynamic>? params,
    bool skipAuth = false,
  }) async {
    calls.add((name, params));
    if (error != null) throw error!;
    return parser({'feedbackId': '11111111-2222-3333-4444-555555555555'});
  }
}

void main() {
  test('sends kind, message, area, rating and app version', () async {
    final api = _FakeApi();
    final repo = FeedbackRepository(api, appVersion: () async => '1.0.0+2');
    final result = await repo.send(
      kind: FeedbackKind.idea,
      message: '  Show the driver’s car colour  ',
      area: FeedbackArea.liveRide,
      rating: 4,
    );
    expect(result.isRight(), isTrue);
    final (name, params) = api.calls.single;
    expect(name, 'submit_app_feedback');
    expect(params!['kind'], 'idea');
    expect(params['message'], 'Show the driver’s car colour');
    expect(params['area'], 'live_ride');
    expect(params['rating'], 4);
    expect(params['app_version'], '1.0.0+2');
    expect(params.containsKey('platform'), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(api.functions, ['notify-feedback']);
  });

  test('optional fields are left out; SQL not applied says so', () async {
    final api = _FakeApi()
      ..error = const ServerException('Not found', 404, 'PGRST202');
    final repo = FeedbackRepository(api, appVersion: () async => '1.0.0+2');
    final result = await repo.send(
      kind: FeedbackKind.problem,
      message: 'Map is blank',
    );
    final (_, params) = api.calls.single;
    expect(params!.containsKey('area'), isFalse);
    expect(params.containsKey('rating'), isFalse);
    expect(
      result.getLeft().toNullable()?.message,
      contains('isn’t available yet'),
    );
    expect(api.functions, isEmpty);
  });

  test('uploads attachments with the feedback id, at most 3', () async {
    final api = _FakeApi();
    final repo = FeedbackRepository(api, appVersion: () async => '1.0.0+2');
    final paths = [for (var i = 0; i < 4; i++) await _tempImage('s$i.jpg')];
    final result = await repo.send(
      kind: FeedbackKind.problem,
      message: 'Map is blank',
      attachments: paths,
    );
    expect(result.getOrElse((_) => false), isTrue);
    final form = api.uploads.single;
    expect(form.fields.single.key, 'feedbackId');
    expect(form.fields.single.value, '11111111-2222-3333-4444-555555555555');
    expect([for (final f in form.files) f.key], ['file0', 'file1', 'file2']);
  });

  test('upload fails: feedback still saved, reported as partial', () async {
    final api = _FakeApi()..uploadFails = true;
    final repo = FeedbackRepository(api, appVersion: () async => '1.0.0+2');
    final result = await repo.send(
      kind: FeedbackKind.problem,
      message: 'Map is blank',
      attachments: [await _tempImage('a.jpg')],
    );
    expect(result.isRight(), isTrue);
    expect(result.getOrElse((_) => true), isFalse);
    await Future<void>.delayed(Duration.zero);
    // Emailed without the photos.
    expect(api.functions, ['notify-feedback', 'notify-feedback']);
  });

  testWidgets('sheet: add a screenshot, it is sent with the feedback', (
    tester,
  ) async {
    final api = _FakeApi();
    final shot = await tester.runAsync(() => _tempImage('shot.jpg'));
    await sl.reset();
    sl
      ..registerSingleton<FeedbackRepository>(
        FeedbackRepository(api, appVersion: () async => '1.0.0+2'),
      )
      ..registerSingleton<PhotoPicker>(_FakePicker(shot!));
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => openFeedback(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Attachments (optional)'), findsOneWidget);

    await tester.ensureVisible(find.bySemanticsLabel('Add attachment'));
    await tester.tap(find.bySemanticsLabel('Add attachment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose a screenshot or photo'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Remove attachment'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Button overlaps text');
    await tester.pump();
    await tester.ensureVisible(find.text('Send feedback').last);
    await tester.runAsync(() async {
      await tester.tap(find.text('Send feedback').last);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    expect(api.uploads.single.files.single.key, 'file0');
    await sl.reset();
  });

  testWidgets('sheet: Send stays off until something is typed, then sends', (
    tester,
  ) async {
    final api = _FakeApi();
    await sl.reset();
    sl.registerSingleton<FeedbackRepository>(
      FeedbackRepository(api, appVersion: () async => '1.0.0+2'),
    );
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => openFeedback(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final send = find.widgetWithText(ElevatedButton, 'Send feedback');
    await tester.tap(find.text('Suggest an improvement'));
    await tester.pump();
    await tester.ensureVisible(find.text('Send feedback').last);
    await tester.tap(find.text('Send feedback').last);
    await tester.pump();
    expect(api.calls, isEmpty);

    await tester.enterText(find.byType(TextField), 'Add a dark mode');
    await tester.pump();
    await tester.tap(find.byTooltip('5 of 5'));
    await tester.pump();
    await tester.ensureVisible(find.text('Send feedback').last);
    await tester.tap(find.text('Send feedback').last);
    await tester.pumpAndSettle();

    final (_, params) = api.calls.single;
    expect(params!['kind'], 'idea');
    expect(params['message'], 'Add a dark mode');
    expect(params['rating'], 5);
    expect(
      find.text('Thanks! Your feedback was sent to the KidsPool team.'),
      findsOneWidget,
    );
    expect(send, findsNothing);
    await sl.reset();
  });

  testWidgets('screen: back arrow returns without sending', (tester) async {
    final api = _FakeApi();
    await sl.reset();
    sl.registerSingleton<FeedbackRepository>(
      FeedbackRepository(api, appVersion: () async => '1.0.0+2'),
    );
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => openFeedback(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(FeedbackScreen), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(FeedbackScreen), findsNothing);
    expect(find.text('open'), findsOneWidget);
    expect(api.calls, isEmpty);
    await sl.reset();
  });
}

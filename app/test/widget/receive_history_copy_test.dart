import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/model/persistence/color_mode.dart';
import 'package:localsend_app/model/persistence/receive_history_entry.dart';
import 'package:localsend_app/pages/receive_history_page.dart';
import 'package:localsend_app/provider/persistence_provider.dart';
import 'package:localsend_isolates/model/file_type.dart';
import 'package:mockito/mockito.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:system_date_time_format/system_date_time_format.dart';

import '../mocks.mocks.dart';

void main() {
  setUpAll(initializeDateFormatting);
  final copyButton = find.byWidgetPredicate((widget) => widget is IconButton && widget.tooltip == 'Copy received file names');

  testWidgets('copies only received file names in history order', (tester) async {
    final copied = await _pumpHistory(tester, [
      _entry('1', 'Packing List.pdf', FileType.pdf),
      _entry('2', 'Meet at the receiving dock', FileType.text, isMessage: true),
      _entry('3', 'Delivery Notes.txt', FileType.text),
    ]);

    await tester.tap(copyButton);
    await tester.pumpAndSettle();

    expect(copied, ['Packing List.pdf\nDelivery Notes.txt']);
    expect(find.text('Copied 2 file names to clipboard'), findsOneWidget);
  });

  testWidgets('disables copying when history contains only messages', (tester) async {
    final copied = await _pumpHistory(tester, [
      _entry('1', 'Meet at the receiving dock', FileType.text, isMessage: true),
    ]);

    expect(tester.widget<IconButton>(copyButton).onPressed, isNull);
    expect(copied, isEmpty);
  });
}

Future<List<String>> _pumpHistory(WidgetTester tester, List<ReceiveHistoryEntry> entries) async {
  final persistence = MockPersistenceService();
  when(persistence.getReceiveHistory()).thenReturn(entries);

  final copied = <String>[];
  final messenger = tester.binding.defaultBinaryMessenger;
  const timeFormatChannel = MethodChannel('system_date_time_format');
  messenger.setMockMethodCallHandler(timeFormatChannel, (_) async => null);
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.setData') {
      copied.add((call.arguments as Map<Object?, Object?>)['text'] as String);
    }
    return null;
  });
  addTearDown(() {
    messenger.setMockMethodCallHandler(timeFormatChannel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  await tester.pumpWidget(
    RefenaScope(
      overrides: [persistenceProvider.overrideWithValue(persistence)],
      child: SDTFScope(
        child: MaterialApp(
          theme: getTheme(ColorMode.localsend, Colors.teal, Brightness.light, null),
          home: const ReceiveHistoryPage(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return copied;
}

ReceiveHistoryEntry _entry(String id, String name, FileType type, {bool isMessage = false}) {
  return ReceiveHistoryEntry(
    id: id,
    fileName: name,
    fileType: type,
    path: null,
    savedToGallery: false,
    isMessage: isMessage,
    fileSize: 1024,
    senderAlias: 'Sender',
    timestamp: DateTime.utc(2026, 1, 1),
  );
}

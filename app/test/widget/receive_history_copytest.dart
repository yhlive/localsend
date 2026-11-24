import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:localsend_app/model/persistence/receive_history_entry.dart';
import 'package:localsend_isolates/model/file_type.dart';
import 'package:mockito/mockito.dart';

import '../mocks.mocks.dart';

void main() {
  setUpAll(initializeDateFormatting);

  testWidgets('can copy a message from the receive history', (tester) async {
    final persistence = MockPersistenceService();
    when(persistence.getReceiveHistory()).thenReturn([
      ReceiveHistoryEntry(
        id: '1',
        fileName: 'test.txt',
        fileType: FileType.pdf,
        path: null,
        savedToGallery: false,
        isMessage: false,
        fileSize: 1024,
        senderAlias: 'Sender',
        timestamp: DateTime.utc(2026, 1, 1),
      ),
    ]);

    String? copiedText;
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/clipboard'),
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedText = call.arguments['text'] as String?;
        }
        return null;
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/clipboard'),
      (call) async {
        if (call.method == 'Clipboard.getData') {
          return {'text': copiedText};
        }
        return null;
      },
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();

    final messageField = find.byType(TextFormField);
    final copyButton = find.byType(FilledButton);

    await tester.enterText(messageField, 'Hello, world!');
    await tester.tap(copyButton);
    await tester.pumpAndSettle();

    expect(copiedText, 'Hello, world!');
  });
}

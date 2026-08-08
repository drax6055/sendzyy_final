import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iFloraBuzz/features/clients/data/models/group_model.dart';
import 'package:iFloraBuzz/features/clients/presentation/widgets/group_card.dart';

GroupModel _makeGroup() => GroupModel(
      id: 'group-1',
      tenantId: 'tenant-1',
      name: 'Test Group',
      clientIds: ['c1', 'c2'],
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

void main() {
  group('GroupCard QR button', () {
    testWidgets('renders QR icon button with correct tooltip', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroupCard(
              group: _makeGroup(),
              onEdit: () {},
              onDelete: () {},
              onQrCode: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.qr_code), findsOneWidget);
      expect(find.byTooltip('Group Registration QR'), findsOneWidget);
    });

    testWidgets('invokes onQrCode callback when tapped', (tester) async {
      var called = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroupCard(
              group: _makeGroup(),
              onEdit: () {},
              onDelete: () {},
              onQrCode: () => called = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.qr_code));
      expect(called, isTrue);
    });

    testWidgets('QR button sits between edit and delete buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroupCard(
              group: _makeGroup(),
              onEdit: () {},
              onDelete: () {},
              onQrCode: () {},
              onDownloadCsv: () {},
            ),
          ),
        ),
      );

      final downloadBtn = tester.getCenter(find.byIcon(Icons.download_outlined));
      final editBtn = tester.getCenter(find.byIcon(Icons.edit_outlined));
      final qrBtn = tester.getCenter(find.byIcon(Icons.qr_code));
      final deleteBtn = tester.getCenter(find.byIcon(Icons.delete_outline));

      // Buttons ordered: download, edit, qr, delete
      expect(editBtn.dx, greaterThan(downloadBtn.dx));
      expect(qrBtn.dx, greaterThan(editBtn.dx));
      expect(deleteBtn.dx, greaterThan(qrBtn.dx));
    });

    testWidgets('renders CSV download button and invokes callback when tapped', (tester) async {
      var called = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroupCard(
              group: _makeGroup(),
              onEdit: () {},
              onDelete: () {},
              onQrCode: () {},
              onDownloadCsv: () => called = true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.download_outlined), findsOneWidget);
      expect(find.byTooltip('Download Group CSV'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.download_outlined));
      expect(called, isTrue);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendzyy/features/clients/data/models/group_model.dart';
import 'package:sendzyy/features/clients/presentation/widgets/group_card.dart';

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
            ),
          ),
        ),
      );

      final editBtn = tester.getCenter(find.byIcon(Icons.edit_outlined));
      final qrBtn = tester.getCenter(find.byIcon(Icons.qr_code));
      final deleteBtn = tester.getCenter(find.byIcon(Icons.delete_outline));

      // QR button x-position is between edit and delete
      expect(qrBtn.dx, greaterThan(editBtn.dx));
      expect(qrBtn.dx, lessThan(deleteBtn.dx));
    });
  });
}

  
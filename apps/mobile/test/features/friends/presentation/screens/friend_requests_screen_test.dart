import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/friends/domain/entities/friend_entity.dart';
import 'package:mobile/features/friends/presentation/providers/friend_action_provider.dart';
import 'package:mobile/features/friends/presentation/providers/incoming_requests_provider.dart';
import 'package:mobile/features/friends/presentation/providers/outgoing_requests_provider.dart';
import 'package:mobile/features/friends/presentation/screens/friend_requests_screen.dart';
import 'package:mobile/features/friends/presentation/widgets/friend_request_tile.dart';
import 'package:network_image_mock/network_image_mock.dart';

const _uid = 'current-uid';

FriendEntity _stubRequest({
  String friendUid = 'other-uid',
  String name = 'Bob Jones',
}) {
  final now = DateTime(2026, 5, 20);
  return FriendEntity(
    friendUid: friendUid,
    status: 'pending',
    initiatorUid: friendUid,
    createdAt: now,
    updatedAt: now,
    friendDisplayName: name,
  );
}

class _FakeActionNotifier extends FriendActionNotifier {
  @override
  AsyncValue<void> build() => const AsyncData(null);
}

Widget _buildScreen({
  AsyncValue<List<FriendEntity>> incoming = const AsyncValue.data([]),
  AsyncValue<List<FriendEntity>> outgoing = const AsyncValue.data([]),
}) {
  return ProviderScope(
    overrides: [
      incomingRequestsProvider(_uid).overrideWith(
        (_) => incoming.when(
          loading: () => const Stream.empty(),
          error: (e, st) => Stream.error(e, st),
          data: (v) => Stream.value(v),
        ),
      ),
      outgoingRequestsProvider(_uid).overrideWith(
        (_) => outgoing.when(
          loading: () => const Stream.empty(),
          error: (e, st) => Stream.error(e, st),
          data: (v) => Stream.value(v),
        ),
      ),
      friendActionNotifierProvider.overrideWith(() => _FakeActionNotifier()),
    ],
    child: const MaterialApp(
      home: FriendRequestsScreen(currentUid: _uid),
    ),
  );
}

void main() {
  testWidgets('FriendRequestsScreen — renders AppBar title', (tester) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.text('Friend Requests'), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  testWidgets(
    'FriendRequestsScreen — loading state shows CircularProgressIndicator',
    (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildScreen(
          incoming: const AsyncValue.loading(),
          outgoing: const AsyncValue.loading(),
        ));
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byType(CircularProgressIndicator), findsWidgets);
      });
    },
  );

  testWidgets(
    'FriendRequestsScreen — empty state shows correct messages',
    (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildScreen());
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(find.text('No incoming requests.'), findsOneWidget);
        expect(find.text('No sent requests.'), findsOneWidget);
      });
    },
  );

  testWidgets(
    'FriendRequestsScreen — populated incoming section renders FriendRequestTile',
    (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildScreen(
          incoming: AsyncValue.data([_stubRequest(name: 'Alice Smith')]),
        ));
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(find.byType(FriendRequestTile), findsOneWidget);
        expect(find.text('Alice Smith'), findsOneWidget);
      });
    },
  );

  testWidgets(
    'FriendRequestsScreen — populated outgoing section renders FriendRequestTile',
    (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildScreen(
          outgoing: AsyncValue.data([
            _stubRequest(friendUid: 'out-uid', name: 'Charlie Brown'),
          ]),
        ));
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(find.byType(FriendRequestTile), findsOneWidget);
        expect(find.text('Charlie Brown'), findsOneWidget);
      });
    },
  );

  testWidgets(
    'FriendRequestsScreen — incoming error shows error message',
    (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildScreen(
          incoming: AsyncValue.error(Exception('network'), StackTrace.empty),
        ));
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(find.text('Could not load requests.'), findsOneWidget);
      });
    },
  );

  testWidgets(
    'FriendRequestsScreen — section headers Incoming and Sent are present',
    (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildScreen());
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(find.text('Incoming'), findsOneWidget);
        expect(find.text('Sent'), findsOneWidget);
      });
    },
  );
}

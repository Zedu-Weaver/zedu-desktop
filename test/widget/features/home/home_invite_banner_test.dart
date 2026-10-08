import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../helpers/helpers.dart';

class TestWorkspaceNotifier extends WorkspaceNotifier {
  static bool missing = false;
  void selectB() {
    state = const WorkspaceState(
      selectedWorkspace: Workspace(
        id: "workspace-b",
        name: "Workspace B",
        avatar: "",
      ),
    );
  }

  @override
  WorkspaceState build() => missing
      ? const WorkspaceState()
      : const WorkspaceState(
          selectedWorkspace: Workspace(
            id: 'workspace-a',
            name: 'Workspace A',
            avatar: '',
          ),
        );
}

class TestProfileNotifier extends UserProfileNotifier {
  static List<String> permissions = [];
  static int checks = 0;
  static int sends = 0;
  static bool fail = false;
  static bool delayed = false;
  @override
  UserProfileState build() => const UserProfileState();
  @override
  Future<Result<List<String>>> getInvitationPermissions({
    required String orgId,
  }) async {
    checks++;
    if (delayed) await Future<void>.delayed(const Duration(milliseconds: 100));
    if (fail) {
      return const Failure(
        ApiFailure(
          message: "Unable to check access. Please try again.",
          kind: ApiFailureKind.client,
        ),
      );
    }
    expect(orgId, 'workspace-a');
    return Success(permissions);
  }

  @override
  Future<void> inviteMember({
    required String email,
    required String role,
    String? userId,
    String? orgId,
  }) async {
    sends++;
  }

  @override
  Future<String?> generateInviteLink({String? orgId}) async {
    sends++;
    return null;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchRegisteredUsers() async => [];
}

void main() {
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workspaceProvider.overrideWith(TestWorkspaceNotifier.new),
          userProfileNotifierProvider.overrideWith(TestProfileNotifier.new),
        ],
        child: buildTestMaterialApp(
          Theme(
            data: AppTheme.light,
            child: const Scaffold(body: InviteTeammatesCard()),
          ),
        ),
      ),
    );
  }

  setUp(() {
    TestWorkspaceNotifier.missing = false;
    TestProfileNotifier.permissions = [];
    TestProfileNotifier.checks = 0;
    TestProfileNotifier.sends = 0;
    TestProfileNotifier.fail = false;
    TestProfileNotifier.delayed = false;
  });
  testWidgets('denied banner explains permission without opening dialog', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Invite teammates'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        "You don't have permission to invite teammates in this workspace.",
      ),
      findsOneWidget,
    );
    expect(find.byType(InviteTeammatesModal), findsNothing);
  });
  testWidgets('chevron opens captured workspace and close returns to banner', (
    tester,
  ) async {
    TestProfileNotifier.permissions = ['can_invite_members'];
    await pump(tester);
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(find.byType(InviteTeammatesModal), findsOneWidget);
    expect(
      tester
          .widget<InviteTeammatesModal>(find.byType(InviteTeammatesModal))
          .workspace
          ?.id,
      'workspace-a',
    );
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();
    expect(find.byType(InviteTeammatesModal), findsNothing);
  });
  testWidgets('permission lookup failure is visible and does not open flow', (
    tester,
  ) async {
    TestProfileNotifier.fail = true;
    await pump(tester);
    await tester.tap(find.text('Invite teammates'));
    await tester.pumpAndSettle();
    expect(
      find.text('Unable to check access. Please try again.'),
      findsOneWidget,
    );
    expect(find.byType(InviteTeammatesModal), findsNothing);
  });
  testWidgets('repeated activation during lookup opens one dialog', (
    tester,
  ) async {
    TestProfileNotifier.permissions = ['can_invite_members'];
    TestProfileNotifier.delayed = true;
    await pump(tester);
    await tester.tap(find.text('Invite teammates'));
    await tester.tap(find.text('Invite teammates'));
    await tester.pumpAndSettle();
    expect(TestProfileNotifier.checks, 1);
    expect(find.byType(InviteTeammatesModal), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'person@example.test');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(InviteTeammatesModal), findsNothing);
    expect(TestProfileNotifier.sends, 0);
    expect(
      tester
          .widget<OutlinedButton>(find.byType(OutlinedButton))
          .focusNode!
          .hasFocus,
      true,
    );
  });
  testWidgets('no selected workspace explains how to proceed without lookup', (
    tester,
  ) async {
    TestWorkspaceNotifier.missing = true;
    await pump(tester);
    await tester.tap(find.text('Invite teammates'));
    await tester.pumpAndSettle();
    expect(
      find.text('Select a workspace before inviting teammates.'),
      findsOneWidget,
    );
    expect(TestProfileNotifier.checks, 0);
  });
  testWidgets('switching workspace while lookup waits keeps captured A', (
    tester,
  ) async {
    TestProfileNotifier.permissions = ['can_invite_members'];
    TestProfileNotifier.delayed = true;
    await pump(tester);
    await tester.tap(find.text('Invite teammates'));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(InviteTeammatesCard)),
    );
    (container.read(workspaceProvider.notifier) as TestWorkspaceNotifier)
        .selectB();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<InviteTeammatesModal>(find.byType(InviteTeammatesModal))
          .workspace
          ?.id,
      'workspace-a',
    );
    expect(find.text('Invite teammates to Workspace A'), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byType(InviteTeammatesModal), findsNothing);
    expect(TestProfileNotifier.sends, 0);
  });
  for (final key in [LogicalKeyboardKey.enter, LogicalKeyboardKey.space]) {
    testWidgets('keyboard activates banner with $key', (tester) async {
      await pump(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
      expect(TestProfileNotifier.checks, 1);
    });
  }
}

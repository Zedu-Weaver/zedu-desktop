import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockRepository extends Mock implements UserProfileRepository {}

class MockApi extends Mock implements ApiBaseService {}

class TestNotifier extends UserProfileNotifier {
  @override
  Future<void> load() async {}
}

class TestAuth extends AuthNotifier {
  @override
  AuthState build() => AuthState(
    user: User(
      id: 'me',
      firstName: '',
      lastName: '',
      email: '',
      phone: '',
      username: '',
      isVerified: true,
      isOnboarded: true,
      createdAt: DateTime(2026),
      currentOrg: 'workspace-b',
      currentOrganisationSlug: '',
      avatarUrl: '',
      defaultAvatarUrl: '',
    ),
  );
}

class TestWorkspace extends WorkspaceNotifier {
  @override
  WorkspaceState build() => const WorkspaceState(
    selectedWorkspace: Workspace(id: 'workspace-b', name: 'B', avatar: ''),
  );
}

void main() {
  late MockRepository repository;
  late MockApi api;
  late ProviderContainer container;
  setUp(() {
    repository = MockRepository();
    api = MockApi();
    locator.registerSingleton<AppConfig>(
      const AppConfig(apiBaseUrl: 'https://example.test/', usesMockData: false),
    );
    locator.registerSingleton<ApiBaseService>(api);
    container = ProviderContainer(
      overrides: [
        userProfileRepositoryProvider.overrideWithValue(repository),
        userProfileNotifierProvider.overrideWith(TestNotifier.new),
        authNotifierProvider.overrideWith(TestAuth.new),
        workspaceProvider.overrideWith(TestWorkspace.new),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await locator.reset();
  });
  void permissions(List<String> keys) {
    when(
      () => repository.getWorkspacePermissions(
        userId: 'me',
        orgId: 'workspace-a',
      ),
    ).thenAnswer((_) async => Success(keys));
  }

  void roles() {
    when(
      () => api.get<Map<String, dynamic>>(
        path: '/organisations/workspace-a/roles',
      ),
    ).thenAnswer(
      (_) async => const ApiResponseModel(
        data: {
          'data': [
            {'id': 'user-role', 'name': 'User'},
            {'id': 'owner-role', 'name': 'Owner'},
          ],
        },
        statusCode: 200,
      ),
    );
  }

  test('explicit workspace stays A while selected workspace is B', () async {
    permissions(['can_invite_members']);
    roles();
    when(
      () => repository.inviteMember(
        email: 'test@example.test',
        role: 'user-role',
        orgId: 'workspace-a',
      ),
    ).thenAnswer(
      (_) async => const Failure(
        ApiFailure(message: 'test failure', kind: ApiFailureKind.client),
      ),
    );
    await container
        .read(userProfileNotifierProvider.notifier)
        .inviteMember(
          email: 'test@example.test',
          role: 'User',
          orgId: 'workspace-a',
        );
    verify(
      () => repository.inviteMember(
        email: 'test@example.test',
        role: 'user-role',
        orgId: 'workspace-a',
      ),
    ).called(1);
  });
  test('revoked permission stops invitation before role lookup', () async {
    permissions([]);
    await container
        .read(userProfileNotifierProvider.notifier)
        .inviteMember(
          email: 'test@example.test',
          role: 'User',
          orgId: 'workspace-a',
        );
    expect(
      container.read(userProfileNotifierProvider).error,
      contains("don't have permission"),
    );
    expect(container.read(userProfileNotifierProvider).isSaving, false);
    verifyZeroInteractions(api);
    verifyNever(
      () => repository.inviteMember(
        email: any(named: 'email'),
        role: any(named: 'role'),
        orgId: any(named: 'orgId'),
      ),
    );
  });
  test('email-only permission cannot generate a link', () async {
    permissions(['can_invite_members']);
    expect(
      await container
          .read(userProfileNotifierProvider.notifier)
          .generateInviteLink(orgId: 'workspace-a'),
      isNull,
    );
    expect(
      container.read(userProfileNotifierProvider).error,
      contains('invite link'),
    );
    verifyZeroInteractions(api);
  });
  test('link uses captured workspace and member role', () async {
    permissions(['can_manage_general_invite_link']);
    roles();
    when(
      () => api.post<Map<String, dynamic>>(
        path: '/invite/general',
        data: {'organisation_id': 'workspace-a', 'role_id': 'user-role'},
      ),
    ).thenAnswer(
      (_) async => const ApiResponseModel(
        data: {
          'data': {'invitation_link': 'https://example.test/invite'},
        },
        statusCode: 201,
      ),
    );
    expect(
      await container
          .read(userProfileNotifierProvider.notifier)
          .generateInviteLink(orgId: 'workspace-a'),
      'https://example.test/invite',
    );
  });
  test(
    'role lookup denial stops link request and preserves feedback',
    () async {
      permissions(['can_manage_general_invite_link']);
      when(
        () => api.get<Map<String, dynamic>>(path: any(named: 'path')),
      ).thenThrow(
        const ApiFailure(message: 'denied', kind: ApiFailureKind.forbidden),
      );
      expect(
        await container
            .read(userProfileNotifierProvider.notifier)
            .generateInviteLink(orgId: 'workspace-a'),
        isNull,
      );
      expect(
        container.read(userProfileNotifierProvider).error,
        "You don't have permission to do that.",
      );
      verifyNever(
        () => api.post<Map<String, dynamic>>(
          path: any(named: 'path'),
          data: any(named: 'data'),
        ),
      );
    },
  );
}

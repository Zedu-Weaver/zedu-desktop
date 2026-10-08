import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockApi extends Mock implements ApiBaseService {}

void main() {
  late MockApi api;
  late UserProfileRemoteDataSourceImpl remote;
  setUp(() {
    api = MockApi();
    remote = UserProfileRemoteDataSourceImpl(
      config: const AppConfig(
        apiBaseUrl: 'https://example.test/',
        usesMockData: false,
      ),
      apiBaseService: api,
    );
  });

  test(
    'reads permissions for the requesting user and captured workspace',
    () async {
      when(
        () => api.get<Map<String, dynamic>>(
          path: '/users/me-id/organisations/workspace-a/roles',
        ),
      ).thenAnswer(
        (_) async => const ApiResponseModel(
          data: {
            'data': {
              'permissions': ['can_invite_members'],
            },
          },
          statusCode: 200,
        ),
      );
      expect(
        await remote.getWorkspacePermissions(
          userId: 'me-id',
          orgId: 'workspace-a',
        ),
        ['can_invite_members'],
      );
    },
  );

  test('omitted permissions deny access', () async {
    when(
      () => api.get<Map<String, dynamic>>(path: any(named: 'path')),
    ).thenAnswer(
      (_) async => const ApiResponseModel(
        data: {
          'data': {'role_id': 'role'},
        },
        statusCode: 200,
      ),
    );
    expect(
      await remote.getWorkspacePermissions(
        userId: 'me-id',
        orgId: 'workspace-a',
      ),
      isEmpty,
    );
  });

  test('malformed permissions return a parsing failure', () async {
    when(
      () => api.get<Map<String, dynamic>>(path: any(named: 'path')),
    ).thenAnswer(
      (_) async => const ApiResponseModel(
        data: {
          'data': {'permissions': 'all'},
        },
        statusCode: 200,
      ),
    );
    final repository = UserProfileRepositoryImpl(remote: remote);
    final result = await repository.getWorkspacePermissions(
      userId: 'me-id',
      orgId: 'workspace-a',
    );
    expect(result, isA<Failure<List<String>>>());
    expect(
      (result as Failure<List<String>>).error.kind,
      ApiFailureKind.parsing,
    );
  });

  test('permission denial is retained through the repository', () async {
    when(
      () => api.get<Map<String, dynamic>>(path: any(named: 'path')),
    ).thenThrow(
      const ApiFailure(
        message: 'denied',
        kind: ApiFailureKind.forbidden,
        statusCode: 403,
      ),
    );
    final result = await UserProfileRepositoryImpl(
      remote: remote,
    ).getWorkspacePermissions(userId: 'me-id', orgId: 'workspace-a');
    expect(
      (result as Failure<List<String>>).error.kind,
      ApiFailureKind.forbidden,
    );
  });
}

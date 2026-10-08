import 'dart:convert';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class UserProfileNotifier extends Notifier<UserProfileState> {
  late final UserProfileRepository _repository;

  @override
  UserProfileState build() {
    _repository = ref.read(userProfileRepositoryProvider);
    load();
    return const UserProfileState(isLoading: true);
  }

  void selectSection(UserProfileSection section) {
    state = state.copyWith(
      section: section,
      clearError: true,
      clearSuccess: true,
    );
  }

  Future<void> updateAccount(ProfileAccount account) async {
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );
    final result = await _repository.updateAccount(account);
    switch (result) {
      case Success<ProfileAccount>():
        state = state.copyWith(
          account: result.value,
          isSaving: false,
          successMessage: 'Account information saved successfully.',
        );
      case Failure<ProfileAccount>():
        state = state.copyWith(
          isSaving: false,
          error: result.error.friendlyMessage,
        );
    }
  }

  Future<void> deleteAccount() async {
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );
    final result = await _repository.deleteAccount();
    switch (result) {
      case Success<void>():
        state = state.copyWith(
          isSaving: false,
          successMessage: 'Account deleted successfully.',
        );
      case Failure<void>():
        state = state.copyWith(
          isSaving: false,
          error: result.error.friendlyMessage,
        );
    }
  }

  Future<void> updateNotificationPreferences(
    NotificationPreferences preferences,
  ) async {
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );
    final result = await _repository.updateNotificationPreferences(preferences);
    switch (result) {
      case Success<NotificationPreferences>():
        state = state.copyWith(
          notifications: result.value,
          isSaving: false,
          successMessage: 'Notification preferences saved successfully.',
        );
      case Failure<NotificationPreferences>():
        state = state.copyWith(
          isSaving: false,
          error: result.error.friendlyMessage,
        );
    }
  }

  Future<void> revertNotificationPreferences(
    NotificationPreferences preferences,
  ) async {
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );
    final result = await _repository.updateNotificationPreferences(preferences);
    switch (result) {
      case Success<NotificationPreferences>():
        state = state.copyWith(
          notifications: result.value,
          isSaving: false,
          successMessage: 'Changes reverted successfully.',
        );
      case Failure<NotificationPreferences>():
        state = state.copyWith(
          isSaving: false,
          error: result.error.friendlyMessage,
        );
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );
    final result = await _repository.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    switch (result) {
      case Success<void>():
        state = state.copyWith(
          isSaving: false,
          successMessage: 'Password updated successfully.',
        );
      case Failure<void>():
        state = state.copyWith(
          isSaving: false,
          error: result.error.friendlyMessage,
        );
    }
  }

  Future<void> updateOrganization(OrganizationProfile organization) async {
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );
    final result = await _repository.updateOrganization(organization);
    switch (result) {
      case Success<OrganizationProfile>():
        state = state.copyWith(
          organization: result.value,
          isSaving: false,
          successMessage: 'Organization information saved successfully.',
        );
      case Failure<OrganizationProfile>():
        state = state.copyWith(
          isSaving: false,
          error: result.error.friendlyMessage,
        );
    }
  }

  Future<void> createOrganization({
    required String name,
    required String type,
    required String country,
  }) async {
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );
    final result = await _repository.createOrganization(
      name: name,
      type: type,
      country: country,
    );
    switch (result) {
      case Success<OrganizationProfile>():
        state = state.copyWith(
          organization: result.value,
          isSaving: false,
          successMessage: 'Organization created successfully.',
        );
        ref
            .read(workspaceProvider.notifier)
            .addWorkspace(
              Workspace(
                id: result.value.id,
                name: result.value.name,
                avatar: '',
                unreadCount: 0,
                membersCount: 1,
              ),
            );
      case Failure<OrganizationProfile>():
        state = state.copyWith(
          isSaving: false,
          error: result.error.friendlyMessage,
        );
    }
  }

  Future<void> deleteOrganization() async {
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );
    final result = await _repository.deleteOrganization();
    switch (result) {
      case Success<void>():
        state = state.copyWith(
          isSaving: false,
          successMessage: 'Organization deleted successfully.',
        );
      case Failure<void>():
        state = state.copyWith(
          isSaving: false,
          error: result.error.friendlyMessage,
        );
    }
  }

  Future<void> leaveOrganization() async {
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );
    try {
      final orgId = ref.read(workspaceProvider).selectedWorkspace?.id;
      final userId = ref.read(authNotifierProvider).user?.id;
      if (orgId == null || userId == null) {
        throw Exception('Missing orgId or userId');
      }

      final api = locator<ApiBaseService>();
      await api.delete<Map<String, dynamic>>(
        path: '/organisations/$orgId/users/$userId',
      );

      // Now remove workspace from local state
      ref.read(workspaceProvider.notifier).removeWorkspace(orgId);

      state = state.copyWith(
        isSaving: false,
        successMessage: 'Successfully signed out of workspace.',
      );
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: 'Failed to leave workspace. Please try again.',
      );
    }
  }

  Future<Result<List<String>>> getInvitationPermissions({
    required String orgId,
  }) async {
    final userId = ref.read(authNotifierProvider).user?.id;
    if (userId == null || userId.isEmpty) {
      return const Failure(
        ApiFailure(
          message: 'Please sign in before inviting teammates.',
          kind: ApiFailureKind.client,
        ),
      );
    }
    return _repository.getWorkspacePermissions(userId: userId, orgId: orgId);
  }

  Future<bool> _checkInvitationPermission(
    String orgId,
    String permission,
  ) async {
    final result = await getInvitationPermissions(orgId: orgId);
    final String? error = switch (result) {
      Success<List<String>>() =>
        result.value.contains(permission)
            ? null
            : permission == 'can_invite_members'
            ? "You don't have permission to invite teammates in this workspace."
            : "You don't have permission to create an invite link in this workspace.",
      Failure<List<String>>() => result.error.friendlyMessage,
    };
    if (error != null) state = state.copyWith(isSaving: false, error: error);
    return error == null;
  }

  Future<String> _getRoleId(String orgId) async {
    if (locator<AppConfig>().usesMockData) return 'mock-user-role';
    final response = await locator<ApiBaseService>().get<Map<String, dynamic>>(
      path: '/organisations/$orgId/roles',
    );
    final roles = response.data['data'] as List<dynamic>;
    final role = roles
        .cast<Map<String, dynamic>>()
        .where((role) => (role['name'] as String?)?.toLowerCase() == 'user')
        .firstOrNull;
    if (role == null) {
      throw const ApiFailure(
        message: 'No member role is available in this workspace.',
        kind: ApiFailureKind.client,
      );
    }
    return role['id'] as String;
  }

  Future<String?> generateInviteLink({String? orgId}) async {
    state = state.copyWith(clearError: true, clearSuccess: true);
    final targetOrgId =
        orgId ?? ref.read(workspaceProvider).selectedWorkspace?.id;
    if (targetOrgId == null || targetOrgId.isEmpty) {
      state = state.copyWith(
        error: 'Select a workspace before inviting teammates.',
      );
      return null;
    }
    if (!await _checkInvitationPermission(
      targetOrgId,
      'can_manage_general_invite_link',
    )) {
      return null;
    }
    if (locator<AppConfig>().usesMockData) {
      state = state.copyWith(
        error: 'Invite links are unavailable in mock mode.',
      );
      return null;
    }
    try {
      final roleId = await _getRoleId(targetOrgId);
      final response = await locator<ApiBaseService>()
          .post<Map<String, dynamic>>(
            path: '/invite/general',
            data: {'organisation_id': targetOrgId, 'role_id': roleId},
          );
      final data = response.data['data'] as Map<String, dynamic>;
      final link = data['invitation_link'] as String?;
      if (link == null || link.isEmpty) {
        throw const ApiFailure(
          message: 'Failed to generate invite link.',
          kind: ApiFailureKind.client,
        );
      }
      return link;
    } catch (error) {
      final failure = error is ApiFailure ? error : ApiFailure.unknown(error);
      state = state.copyWith(error: failure.friendlyMessage);
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchRegisteredUsers() async {
    try {
      final api = locator<ApiBaseService>();
      final response = await api.get<Map<String, dynamic>>(path: '/users');
      final data = response.data['data'] as List<dynamic>?;
      if (data != null) {
        return data.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      // ignore
    }
    return [];
  }

  Future<void> inviteMember({
    required String email,
    required String role,
    String? userId,
    String? orgId,
  }) async {
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );
    final targetOrgId =
        orgId ?? ref.read(workspaceProvider).selectedWorkspace?.id;
    if (targetOrgId == null || targetOrgId.isEmpty) {
      state = state.copyWith(
        isSaving: false,
        error: 'Select a workspace before inviting teammates.',
      );
      return;
    }
    if (!await _checkInvitationPermission(targetOrgId, 'can_invite_members')) {
      return;
    }
    String roleId;
    try {
      roleId = await _getRoleId(targetOrgId);
    } catch (error) {
      final failure = error is ApiFailure ? error : ApiFailure.unknown(error);
      state = state.copyWith(isSaving: false, error: failure.friendlyMessage);
      return;
    }

    final result = await _repository.inviteMember(
      email: email,
      role: roleId,
      orgId: targetOrgId,
    );
    switch (result) {
      case Success<TeamMember>():
        final newTeamMembers = [...state.teamMembers, result.value];
        state = state.copyWith(
          teamMembers: newTeamMembers,
          isSaving: false,
          successMessage: 'Invite sent successfully.',
        );

        // Persist the mock state across restarts if we are using mock data
        final config = locator<AppConfig>();
        if (config.usesMockData) {
          final storage = locator<SecureStorageService>();
          final jsonList = newTeamMembers
              .map(
                (m) => {
                  'id': m.id,
                  'email': m.email,
                  'role': m.role,
                  'name': m.name,
                  'avatar_url': m.avatarUrl,
                  'date_joined': m.dateJoined,
                  'status': m.status.name,
                },
              )
              .toList();
          await storage.writeData(
            'mock_team_members_$targetOrgId',
            jsonEncode(jsonList),
          );
        }

      case Failure<TeamMember>():
        state = state.copyWith(
          isSaving: false,
          error: result.error.friendlyMessage,
        );
    }
  }

  Future<void> updateMember(TeamMember member) async {
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );
    final result = await _repository.updateMember(member);
    switch (result) {
      case Success<TeamMember>():
        state = state.copyWith(
          teamMembers: [
            for (final current in state.teamMembers)
              current.id == result.value.id ? result.value : current,
          ],
          isSaving: false,
          successMessage: 'Team member updated successfully.',
        );
      case Failure<TeamMember>():
        state = state.copyWith(
          isSaving: false,
          error: result.error.friendlyMessage,
        );
    }
  }

  Future<void> removeMember(String memberId) async {
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );
    final result = await _repository.removeMember(memberId);
    switch (result) {
      case Success<void>():
        state = state.copyWith(
          teamMembers: [
            for (final member in state.teamMembers)
              if (member.id != memberId) member,
          ],
          isSaving: false,
          successMessage: 'Team member removed successfully.',
        );
      case Failure<void>():
        state = state.copyWith(
          isSaving: false,
          error: result.error.friendlyMessage,
        );
    }
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final orgId = ref.read(workspaceProvider).selectedWorkspace?.id;
    final results = await Future.wait([
      _repository.getAccount(),
      _repository.getNotificationPreferences(),
      _repository.getSecuritySessions(),
      _repository.getOrganization(),
      _repository.getTeamMembers(orgId: orgId),
      _repository.getRolesAndPermissions(),
      _repository.getBillingInfo(),
    ]);

    final accountResult = results[0] as Result<ProfileAccount>;
    final notificationResult = results[1] as Result<NotificationPreferences>;
    final securityResult = results[2] as Result<List<SecuritySession>>;
    final organizationResult = results[3] as Result<OrganizationProfile>;
    final teamResult = results[4] as Result<List<TeamMember>>;
    final rolesResult = results[5] as Result<List<RolePermission>>;
    final billingResult = results[6] as Result<BillingInfo>;

    final error = _getError(results);

    var loadedTeamMembers = _valueOrNull(teamResult) ?? const [];

    // Load persisted mock members if they exist
    if (orgId != null) {
      final storage = locator<SecureStorageService>();
      final data = await storage.readData('mock_team_members_$orgId');
      if (data != null) {
        try {
          final List<dynamic> decoded = jsonDecode(data) as List<dynamic>;
          final savedMembers = decoded.map((e) {
            final map = e as Map<String, dynamic>;
            return TeamMember(
              id: (map['id'] as String?) ?? '',
              email: (map['email'] as String?) ?? '',
              role: (map['role'] as String?) ?? '',
              name: map['name'] as String?,
              avatarUrl: map['avatar_url'] as String?,
              dateJoined: (map['date_joined'] as String?) ?? '',
              status: TeamMemberStatus.values.firstWhere(
                (s) => s.name == (map['status'] as String?),
                orElse: () => TeamMemberStatus.active,
              ),
            );
          }).toList();
          loadedTeamMembers = savedMembers;
        } catch (_) {}
      }
    }

    state = state.copyWith(
      account: _valueOrNull(accountResult),
      notifications: _valueOrNull(notificationResult),
      securitySessions: _valueOrNull(securityResult) ?? const [],
      organization: _valueOrNull(organizationResult),
      teamMembers: loadedTeamMembers,
      rolesAndPermissions: _valueOrNull(rolesResult) ?? const [],
      billing: _valueOrNull(billingResult),
      isLoading: false,
      error: error,
    );
  }

  String? _getError(List<dynamic> results) {
    for (final result in results) {
      if (result is Failure) {
        return result.error.friendlyMessage;
      }
    }
    return null;
  }

  T? _valueOrNull<T>(Result<T> result) {
    return switch (result) {
      Success<T>() => result.value,
      Failure<T>() => null,
    };
  }
}

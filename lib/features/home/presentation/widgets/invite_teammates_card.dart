import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class InviteTeammatesCard extends ConsumerStatefulWidget {
  const InviteTeammatesCard({super.key});

  @override
  ConsumerState<InviteTeammatesCard> createState() =>
      _InviteTeammatesCardState();
}

class _InviteTeammatesCardState extends ConsumerState<InviteTeammatesCard> {
  bool _opening = false;
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    if (_opening) return;
    _opening = true;
    try {
      final workspace = ref.read(workspaceProvider).selectedWorkspace;
      if (workspace == null) {
        _feedback('Select a workspace before inviting teammates.');
        return;
      }
      final result = await ref
          .read(userProfileNotifierProvider.notifier)
          .getInvitationPermissions(orgId: workspace.id);
      if (!mounted) return;
      switch (result) {
        case Failure<List<String>>():
          _feedback(result.error.friendlyMessage);
        case Success<List<String>>():
          if (!result.value.contains('can_invite_members')) {
            _feedback(
              "You don't have permission to invite teammates in this workspace.",
            );
            return;
          }
          await showDialog<void>(
            context: context,
            builder: (_) => InviteTeammatesModal(workspace: workspace),
          );
      }
    } finally {
      _opening = false;
      if (mounted) _focusNode.requestFocus();
    }
  }

  void _feedback(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return OutlinedButton(
      focusNode: _focusNode,
      onPressed: _open,
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.zero,
        side: BorderSide(color: colors.divider),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colors.primaryBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.person_add_outlined, color: colors.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Invite teammates',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add more team members to collaborate',
                    style: TextStyle(color: colors.textHint, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colors.textHint),
          ],
        ),
      ),
    );
  }
}

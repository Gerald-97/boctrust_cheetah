import 'package:equatable/equatable.dart';

/// Whether the server allows this account to be deleted now. The client never
/// works this out itself: a positive balance blocks deletion, and only the
/// server knows the balance across every account.
class AccountDeletionEligibility extends Equatable {
  const AccountDeletionEligibility({
    required this.canDelete,
    this.blockingBalance,
  });

  final bool canDelete;

  /// The server-formatted balance that must be moved out first, when
  /// [canDelete] is false.
  final String? blockingBalance;

  @override
  List<Object?> get props => [canDelete, blockingBalance];
}

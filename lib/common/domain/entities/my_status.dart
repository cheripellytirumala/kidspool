import 'package:equatable/equatable.dart';

/// `profiles.onboarding_status`: identity review progress.
enum OnboardingStatus {
  notStarted,
  pendingReview,
  approved,
  rejected;

  /// Also reads `profiles.driver_status` (`not_submitted` = not started).
  static OnboardingStatus parse(String? value) => switch (value) {
    'pending_review' => pendingReview,
    'approved' => approved,
    'rejected' => rejected,
    _ => notStarted,
  };
}

/// The user's own gender (optional; `profiles.gender`). Display-only.
enum Gender {
  female('female', 'Female'),
  male('male', 'Male'),
  nonBinary('non_binary', 'Non-binary'),
  preferNotToSay('prefer_not_to_say', 'Prefer not to say');

  const Gender(this.value, this.label);

  /// Value sent to / read from the server.
  final String value;
  final String label;

  /// `null` when not set (or an unknown value).
  static Gender? parse(String? value) {
    for (final gender in values) {
      if (gender.value == value) return gender;
    }
    return null;
  }

  /// "Female" … or "Not set".
  static String labelOf(Gender? gender) => gender?.label ?? 'Not set';
}

/// The signed-in user's onboarding state (`get_my_status`).
class MyStatus extends Equatable {
  const MyStatus({
    required this.role,
    required this.firstName,
    required this.lastName,
    required this.onboardingStatus,
    required this.rejectionReason,
    required this.kidsCount,
    required this.hasDefaultAddress,
    this.licenseStatus = OnboardingStatus.notStarted,
    this.licenseRejectionReason,
    this.gender,
  });

  /// `parent`, `staff` or `null` while not chosen yet.
  final String? role;
  final String firstName;
  final String lastName;
  final OnboardingStatus onboardingStatus;

  /// Why the ID was rejected (when [onboardingStatus] is rejected).
  final String? rejectionReason;
  final int kidsCount;
  final bool hasDefaultAddress;

  /// `profiles.driver_status`: the driver's license review, separate from
  /// the account ([onboardingStatus]), which riders get without a license.
  final OnboardingStatus licenseStatus;
  final String? licenseRejectionReason;

  /// Optional; `null` when not set.
  final Gender? gender;

  /// A driver's license was checked and approved.
  bool get isLicenseVerified => licenseStatus == OnboardingStatus.approved;

  bool get hasRole => role != null;
  bool get isApproved => onboardingStatus == OnboardingStatus.approved;

  /// The ID was sent (in review or approved): the parent may use the app.
  bool get hasSubmittedId =>
      onboardingStatus == OnboardingStatus.pendingReview || isApproved;

  MyStatus withGender(Gender? gender) => MyStatus(
    role: role,
    firstName: firstName,
    lastName: lastName,
    onboardingStatus: onboardingStatus,
    rejectionReason: rejectionReason,
    kidsCount: kidsCount,
    hasDefaultAddress: hasDefaultAddress,
    licenseStatus: licenseStatus,
    licenseRejectionReason: licenseRejectionReason,
    gender: gender,
  );

  @override
  List<Object?> get props => [
    role,
    firstName,
    lastName,
    onboardingStatus,
    rejectionReason,
    kidsCount,
    hasDefaultAddress,
    licenseStatus,
    licenseRejectionReason,
    gender,
  ];
}

/// Centralized status normalization for ride and reservation statuses.
///
/// All status comparisons should use this helper to avoid
/// case-sensitivity bugs between backend and frontend.

/// Normalize any status string to trimmed uppercase.
/// Returns empty string if null.
String normalizeStatus(String? status) {
  return status?.trim().toUpperCase() ?? '';
}

/// Terminal ride statuses — ride is no longer active.
const Set<String> _terminalRideStatuses = {'COMPLETED', 'CANCELLED'};

/// Check if a ride status represents an active (non-terminal) ride.
bool isRideStatusActive(String? status) {
  final normalized = normalizeStatus(status);
  if (normalized.isEmpty) return false;
  return !_terminalRideStatuses.contains(normalized);
}

/// Check if a reservation status is CONFIRMED.
bool isReservationConfirmed(String? status) {
  return normalizeStatus(status) == 'CONFIRMED';
}

// lib/features/issues/models/location.dart
class IssueLocation {
  final String areaName;
  final String wardNumber;
  final double? latitude;   // Real GPS from geolocator
  final double? longitude;  // Real GPS from geolocator

  const IssueLocation({
    required this.areaName,
    required this.wardNumber,
    this.latitude,
    this.longitude,
  });

  String get displayName => '$areaName, Ward $wardNumber';

  bool get hasCoordinates => latitude != null && longitude != null;

  String get coordinatesString {
    if (!hasCoordinates) return 'No location';
    return '${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}';
  }

  IssueLocation copyWith({
    String? areaName,
    String? wardNumber,
    double? latitude,
    double? longitude,
  }) {
    return IssueLocation(
      areaName: areaName ?? this.areaName,
      wardNumber: wardNumber ?? this.wardNumber,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}

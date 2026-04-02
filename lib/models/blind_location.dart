class BlindLocation {
  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final double? altitudeMeters;
  final double? speedMps;
  final double? headingDegrees;
  final String? provider;
  final DateTime? capturedAt;
  final DateTime? updatedAt;

  const BlindLocation({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    this.altitudeMeters,
    this.speedMps,
    this.headingDegrees,
    this.provider,
    this.capturedAt,
    this.updatedAt,
  });

  factory BlindLocation.fromJson(Map<String, dynamic> json) {
    return BlindLocation(
      latitude: _parseDouble(json['latitude']) ?? 0,
      longitude: _parseDouble(json['longitude']) ?? 0,
      accuracyMeters: _parseDouble(json['accuracy_meters']),
      altitudeMeters: _parseDouble(json['altitude_meters']),
      speedMps: _parseDouble(json['speed_mps']),
      headingDegrees: _parseDouble(json['heading_degrees']),
      provider: _parseString(json['provider']),
      capturedAt: _parseDateTime(json['captured_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  BlindLocation copyWith({
    double? latitude,
    double? longitude,
    double? accuracyMeters,
    double? altitudeMeters,
    double? speedMps,
    double? headingDegrees,
    String? provider,
    DateTime? capturedAt,
    DateTime? updatedAt,
  }) {
    return BlindLocation(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracyMeters: accuracyMeters ?? this.accuracyMeters,
      altitudeMeters: altitudeMeters ?? this.altitudeMeters,
      speedMps: speedMps ?? this.speedMps,
      headingDegrees: headingDegrees ?? this.headingDegrees,
      provider: provider ?? this.provider,
      capturedAt: capturedAt ?? this.capturedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toUploadJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      if (accuracyMeters != null) 'accuracy_meters': accuracyMeters,
      if (altitudeMeters != null) 'altitude_meters': altitudeMeters,
      if (speedMps != null) 'speed_mps': speedMps,
      if (headingDegrees != null) 'heading_degrees': headingDegrees,
      if (provider != null && provider!.isNotEmpty) 'provider': provider,
      if (capturedAt != null)
        'captured_at': capturedAt!.toUtc().toIso8601String(),
    };
  }
}

double? _parseDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}

DateTime? _parseDateTime(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value)?.toUtc();
  }
  return null;
}

String? _parseString(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

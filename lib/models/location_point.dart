class LocationPoint {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? accuracy;
  final double? altitude;
  final double? speed;
  final double? heading;

  const LocationPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.accuracy,
    this.altitude,
    this.speed,
    this.heading,
  });

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toUtc().toIso8601String(),
      if (accuracy != null) 'accuracy': accuracy,
      if (altitude != null) 'altitude': altitude,
      if (speed != null) 'speed': speed,
      if (heading != null) 'heading': heading,
    };
  }

  factory LocationPoint.fromJson(Map<String, dynamic> json) {
    return LocationPoint(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      altitude: (json['altitude'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble(),
      heading: (json['heading'] as num?)?.toDouble(),
    );
  }
}

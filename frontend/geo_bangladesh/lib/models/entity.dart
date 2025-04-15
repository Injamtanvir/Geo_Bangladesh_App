class Entity {
  final int? id;
  final String title;
  final double lat;
  final double lon;
  final String? image;
  final Map<String, dynamic>? properties;

  Entity({
    this.id,
    required this.title,
    required this.lat,
    required this.lon,
    this.image,
    this.properties,
  });

  // Factory method to create an Entity from a JSON map
  factory Entity.fromJson(Map<String, dynamic> json) {
    return Entity(
      id: json['id'] is String ? int.parse(json['id']) : json['id'],
      title: json['title'],
      lat: json['lat'] is String ? double.parse(json['lat']) : json['lat'],
      lon: json['lon'] is String ? double.parse(json['lon']) : json['lon'],
      image: json['image'],
      properties: json['properties'],
    );
  }

  // Method to convert an Entity to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'lat': lat,
      'lon': lon,
      'image': image,
      'properties': properties,
    };
  }

  // Method to create a copy of an Entity with some properties changed
  Entity copyWith({
    int? id,
    String? title,
    double? lat,
    double? lon,
    String? image,
    Map<String, dynamic>? properties,
  }) {
    return Entity(
      id: id ?? this.id,
      title: title ?? this.title,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      image: image ?? this.image,
      properties: properties ?? this.properties,
    );
  }
}
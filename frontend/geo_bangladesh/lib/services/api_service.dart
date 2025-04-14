import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/entity.dart';

class ApiService {
  // Geoapify API Key
  static const String apiKey = 'e7ce92dfdb12441ea2da31022f2e963e';

  // Base URL for Geoapify
  static const String geoDataBaseUrl = 'https://api.geoapify.com/v1';

  // Local storage keys
  static const String entitiesStorageKey = 'stored_entities';
  static const String nextIdKey = 'next_entity_id';

  // Local storage for entities
  static List<Entity> _localEntities = [];
  static int _nextEntityId = 1;

  // Initialize with some sample data for Bangladesh
  static bool _initialized = false;

  // Fetch all entities from local storage or initialize with sample data
  Future<List<Entity>> getEntities() async {
    try {
      print('getEntities called, initialized: $_initialized');

      // If not initialized, try loading from storage or create sample data
      if (!_initialized) {
        final loaded = await _loadEntitiesFromStorage();
        if (!loaded) {
          await _initializeEntities();
        }
        _initialized = true;
      }

      return _localEntities;
    } catch (e) {
      print('Error in getEntities: $e');
      // Return empty list rather than throwing to avoid red screen
      return [];
    }
  }

  // Try loading entities from SharedPreferences
  Future<bool> _loadEntitiesFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? entitiesJson = prefs.getString(entitiesStorageKey);
      final int? nextId = prefs.getInt(nextIdKey);

      if (entitiesJson != null) {
        final List<dynamic> decoded = json.decode(entitiesJson);
        _localEntities = decoded.map((e) => Entity.fromJson(e)).toList();
        _nextEntityId = nextId ?? _localEntities.length + 1;
        print('Loaded ${_localEntities.length} entities from storage');
        return true;
      }
      return false;
    } catch (e) {
      print('Error loading entities from storage: $e');
      return false;
    }
  }

  // Save entities to SharedPreferences
  Future<void> _saveEntitiesToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encodedEntities = json.encode(
          _localEntities.map((e) => e.toJson()).toList()
      );
      await prefs.setString(entitiesStorageKey, encodedEntities);
      await prefs.setInt(nextIdKey, _nextEntityId);
      print('Saved ${_localEntities.length} entities to storage');
    } catch (e) {
      print('Error saving entities to storage: $e');
    }
  }

  // Initialize with sample data
  Future<void> _initializeEntities() async {
    try {
      print('Initializing entities');
      // Clear existing entities
      _localEntities.clear();

      // Add some sample entities around Bangladesh
      _localEntities.add(
          Entity(
            id: _nextEntityId++,
            title: 'Dhaka City',
            lat: 23.8103,
            lon: 90.4125,
            image: 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/9d/Sangsad_Bhaban_%28House_of_Parliament%29_in_Dhaka%2C_Bangladesh.jpg/800px-Sangsad_Bhaban_%28House_of_Parliament%29_in_Dhaka%2C_Bangladesh.jpg',
          )
      );

      _localEntities.add(
          Entity(
            id: _nextEntityId++,
            title: 'Chittagong',
            lat: 22.3569,
            lon: 91.7832,
            image: 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c0/Chittagong_City.jpg/800px-Chittagong_City.jpg',
          )
      );

      _localEntities.add(
          Entity(
            id: _nextEntityId++,
            title: 'Cox\'s Bazar',
            lat: 21.4272,
            lon: 92.0058,
            image: 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/5c/Cox%27s_Bazar_Beach.JPG/800px-Cox%27s_Bazar_Beach.JPG',
          )
      );

      // Save initial entities to storage
      await _saveEntitiesToStorage();

      // Get nearby places from Geoapify - but don't wait for it
      // This way we have at least some data even if the API call fails
      _addNearbyPlaces().catchError((e) {
        print('Error fetching nearby places: $e');
      });

      print('Added initial entities: ${_localEntities.length}');
    } catch (e) {
      print('Error initializing entities: $e');
    }
  }

  // Add nearby places using Geoapify Places API
  Future<void> _addNearbyPlaces() async {
    try {
      // Center of Bangladesh
      double lat = 23.6850;
      double lon = 90.3563;

      print('Fetching nearby places from Geoapify');

      // Fetch tourist attractions near Bangladesh center
      final response = await http.get(
          Uri.parse('$geoDataBaseUrl/places?categories=tourism.attraction&filter=circle:$lon,$lat,50000&limit=10&apiKey=$apiKey')
      );

      if (response.statusCode == 200) {
        print('Geoapify places API responded with status 200');
        final data = json.decode(response.body);

        if (data != null && data['features'] != null) {
          print('Found ${data['features'].length} places');

          for (var feature in data['features']) {
            if (feature != null &&
                feature['geometry'] != null &&
                feature['geometry']['coordinates'] != null &&
                feature['properties'] != null &&
                feature['properties']['name'] != null) {

              // Extract coordinates and properties
              final coords = feature['geometry']['coordinates'];
              final name = feature['properties']['name'];

              // Create new entity
              _localEntities.add(
                  Entity(
                    id: _nextEntityId++,
                    title: name,
                    lon: coords[0].toDouble(), // Ensure double type
                    lat: coords[1].toDouble(), // Ensure double type
                    image: 'https://via.placeholder.com/800x600?text=No+Image',
                    properties: feature['properties'],
                  )
              );
            }
          }

          // Save updated entities to storage
          await _saveEntitiesToStorage();

          print('Added ${data['features'].length} places to entities');
        }
      } else {
        print('Geoapify places API responded with status ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching nearby places: $e');
      // Continue with existing entities if Geoapify fetch fails
    }
  }

  // Create a new entity with image (Mobile only)
  Future<int> createEntity(String title, double lat, double lon, File image) async {
    if (kIsWeb) {
      throw Exception('createEntity with File is not supported on web. Use createEntityWithoutImage instead.');
    }

    try {
      // Create new entity without image (since we can't upload in this implementation)
      return await createEntityWithoutImage(title, lat, lon);
    } catch (e) {
      print('Error creating entity: $e');
      throw Exception('Failed to create entity: $e');
    }
  }


  Future<int> createEntityWithoutImage(String title, double lat, double lon) async {
    try {
      // Check if similar entity already exists (same title and coordinates)
      final existingIndex = _localEntities.indexWhere((entity) =>
      entity.title == title &&
          entity.lat == lat &&
          entity.lon == lon);

      if (existingIndex >= 0) {
        // Entity already exists, return its ID
        return _localEntities[existingIndex].id!;
      }

      // Get location information from Geoapify
      final locationInfo = await getLocationInfo(lat, lon);

      // Create new entity
      final newEntity = Entity(
        id: _nextEntityId++,
        title: title,
        lat: lat,
        lon: lon,
        // Use a placeholder image URL
        image: 'https://via.placeholder.com/800x600?text=${Uri.encodeComponent(title)}',
        properties: locationInfo['features'] != null && locationInfo['features'].isNotEmpty ?
        locationInfo['features'][0]['properties'] : null,
      );

      // Add to local storage
      _localEntities.add(newEntity);

      // Save to persistent storage
      await _saveEntitiesToStorage();

      // Return the new entity ID
      return newEntity.id!;
    } catch (e) {
      print('Error creating entity: $e');
      throw Exception('Failed to create entity: $e');
    }
  }




  // Update an existing entity
  Future<bool> updateEntity(int id, String title, double lat, double lon, [File? image]) async {
    try {
      // Find the entity to update
      final index = _localEntities.indexWhere((entity) => entity.id == id);

      if (index >= 0) {
        // Get location information if coordinates changed
        final oldEntity = _localEntities[index];
        Map<String, dynamic>? properties = oldEntity.properties;

        if (oldEntity.lat != lat || oldEntity.lon != lon) {
          final locationInfo = await getLocationInfo(lat, lon);
          if (locationInfo['features'] != null && locationInfo['features'].isNotEmpty) {
            properties = locationInfo['features'][0]['properties'];
          }
        }

        // Update the entity
        _localEntities[index] = Entity(
          id: id,
          title: title,
          lat: lat,
          lon: lon,
          // Keep the existing image
          image: _localEntities[index].image,
          properties: properties,
        );

        // Save to persistent storage
        await _saveEntitiesToStorage();

        return true;
      } else {
        throw Exception('Entity not found');
      }
    } catch (e) {
      print('Error updating entity: $e');
      throw Exception('Failed to update entity: $e');
    }
  }

  // Get geocoding information for a location using Geoapify
  Future<Map<String, dynamic>> getLocationInfo(double lat, double lon) async {
    try {
      print('Getting location info for $lat, $lon');

      final response = await http.get(
          Uri.parse('$geoDataBaseUrl/geocode/reverse?lat=$lat&lon=$lon&apiKey=$apiKey')
      );

      if (response.statusCode == 200) {
        print('Geocoding API responded with status 200');
        final result = json.decode(response.body);
        return result ?? {};
      } else {
        print('Geocoding API error: ${response.statusCode}');
        return {};
      }
    } catch (e) {
      print('Error getting location info: $e');
      return {};
    }
  }

  // Delete an entity
  Future<bool> deleteEntity(int id) async {
    try {
      final index = _localEntities.indexWhere((entity) => entity.id == id);

      if (index >= 0) {
        _localEntities.removeAt(index);
        await _saveEntitiesToStorage();
        return true;
      }
      return false;
    } catch (e) {
      print('Error deleting entity: $e');
      return false;
    }
  }

  // Get the full image URL
  static String getImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return 'https://via.placeholder.com/800x600?text=No+Image';
    }

    // Check if it's already a full URL
    if (imagePath.startsWith('http')) {
      return imagePath;
    }

    // Fallback to placeholder
    return 'https://via.placeholder.com/800x600?text=Image+Not+Found';
  }
}
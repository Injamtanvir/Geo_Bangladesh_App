import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/entity.dart';
import '../database/database_helper.dart';

class ApiService {
  // API URL - Update with your Render deployment URL
  static const String baseUrl = 'https://geo-bangladesh-app.onrender.com';
  static const String apiUrl = '$baseUrl/api/entities/';
  static const String loginUrl = '$baseUrl/api/login/';
  static const String registerUrl = '$baseUrl/api/register/';
  static const String logoutUrl = '$baseUrl/api/logout/';
  static const String imageBaseUrl = '$baseUrl';

  // Auth token storage key
  static const String authTokenKey = 'auth_token';
  static String? _authToken;

  // Database helper for offline caching
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Initialize with auth token if available
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString(authTokenKey);

    if (_authToken == null) {
      // Try to get token from database
      _authToken = await _dbHelper.getAuthToken();
    }
  }

  // Check connectivity
  Future<bool> isConnected() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  // Get auth headers
  Map<String, String> _getHeaders({bool isMultipart = false}) {
    final Map<String, String> headers = {};

    if (_authToken != null) {
      headers['Authorization'] = 'Token $_authToken';
    }

    if (!isMultipart) {
      headers['Content-Type'] = 'application/json';
    }

    return headers;
  }

  // Login user
  Future<bool> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse(loginUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true && data.containsKey('token')) {
          _authToken = data['token'];
          // Save token to shared preferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(authTokenKey, _authToken!);

          // Save to local database
          await _dbHelper.saveUserAuth(username, _authToken!);

          // Sync any offline changes
          await syncOfflineChanges();

          return true;
        }
      }
      return false;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  // Register a new user
  Future<bool> register(String username, String password, String email) async {
    try {
      final response = await http.post(
        Uri.parse(registerUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'password': password,
          'email': email,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true && data.containsKey('token')) {
          _authToken = data['token'];
          // Save token to shared preferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(authTokenKey, _authToken!);

          // Save to local database
          await _dbHelper.saveUserAuth(username, _authToken!);

          return true;
        }
      }
      return false;
    } catch (e) {
      print('Registration error: $e');
      return false;
    }
  }

  // Logout user
  Future<void> logout() async {
    try {
      if (_authToken != null && await isConnected()) {
        await http.post(
          Uri.parse(logoutUrl),
          headers: _getHeaders(),
        );
      }
    } catch (e) {
      print('Logout error: $e');
    } finally {
      _authToken = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(authTokenKey);
      await _dbHelper.clearAuthInfo();
    }
  }

  // Check if user is logged in
  bool isLoggedIn() {
    return _authToken != null;
  }

  // Fetch all entities from API or local cache
  Future<List<Entity>> getEntities() async {
    try {
      final bool connected = await isConnected();

      if (connected) {
        // Try to sync any pending changes first
        if (isLoggedIn()) {
          await syncOfflineChanges();
        }

        // Then fetch updated data
        final response = await http.get(
          Uri.parse(apiUrl),
          headers: _getHeaders(),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          final List<Entity> entities = data.map((json) {
            // Map the Django API response to Entity object
            return Entity(
              id: json['id'],
              title: json['title'],
              lat: json['lat'],
              lon: json['lon'],
              image: json['image'],
              properties: json['properties'],
            );
          }).toList();

          // Cache entities in local database
          await _dbHelper.deleteAllEntities();
          for (var entity in entities) {
            await _dbHelper.insertEntity(entity);
          }

          // Download images for offline use
          await _dbHelper.downloadAllImagesForOffline(entities);

          return entities;
        } else {
          throw Exception('Failed to load entities: ${response.statusCode}');
        }
      } else {
        // Offline mode - use cached data
        print('Device is offline, using cached data');
        return await _dbHelper.getEntities();
      }
    } catch (e) {
      print('Network error, trying to load from cache: $e');
      // If network fails, try to get from local database
      return await _dbHelper.getEntities();
    }
  }

  // Sync changes made while offline
  Future<bool> syncOfflineChanges() async {
    if (!isLoggedIn() || !await isConnected()) {
      return false;
    }

    try {
      final actions = await _dbHelper.getUnsyncedActions();
      if (actions.isEmpty) {
        return true;
      }

      final successfulSyncs = <int>[];

      for (var action in actions) {
        try {
          final actionType = action['action_type'];
          final entityId = action['entity_id'];
          final entityDataJson = action['entity_data'];

          if (actionType == 'create' && entityDataJson != null) {
            final entityData = json.decode(entityDataJson);
            final response = await http.post(
              Uri.parse(apiUrl),
              headers: _getHeaders(),
              body: json.encode({
                'title': entityData['title'],
                'lat': entityData['lat'],
                'lon': entityData['lon'],
                // Image will need to be handled separately for create operations
              }),
            );

            if (response.statusCode == 201) {
              successfulSyncs.add(action['id']);

              // Update local entity with real ID
              final Map<String, dynamic> responseData = json.decode(response.body);
              if (responseData.containsKey('id')) {
                // Get the temporary entity
                final tempEntity = await _dbHelper.getEntityById(entityId);
                if (tempEntity != null) {
                  // Delete the temp entity
                  await _dbHelper.deleteEntity(entityId);

                  // Create a new entity with the real ID
                  final newEntity = Entity(
                    id: responseData['id'],
                    title: tempEntity.title,
                    lat: tempEntity.lat,
                    lon: tempEntity.lon,
                    image: responseData['image'],
                    properties: tempEntity.properties,
                  );

                  await _dbHelper.insertEntity(newEntity);
                }
              }
            }
          } else if (actionType == 'update' && entityDataJson != null) {
            final entityData = json.decode(entityDataJson);
            final response = await http.put(
              Uri.parse('$apiUrl$entityId/'),
              headers: _getHeaders(),
              body: json.encode({
                'title': entityData['title'],
                'lat': entityData['lat'],
                'lon': entityData['lon'],
                // Image will need to be handled separately for updates
              }),
            );

            if (response.statusCode == 200) {
              successfulSyncs.add(action['id']);

              // Update the local entity status
              final entity = await _dbHelper.getEntityById(entityId);
              if (entity != null) {
                await _dbHelper.updateEntity(entity);
              }
            }
          } else if (actionType == 'delete') {
            final response = await http.delete(
              Uri.parse('$apiUrl$entityId/'),
              headers: _getHeaders(),
            );

            if (response.statusCode == 204) {
              successfulSyncs.add(action['id']);
            }
          }
        } catch (e) {
          print('Error syncing action ${action['id']}: $e');
        }
      }

      // Clear synced actions
      if (successfulSyncs.isNotEmpty) {
        await _dbHelper.clearSyncedActions(successfulSyncs);
      }

      return true;
    } catch (e) {
      print('Error syncing offline changes: $e');
      return false;
    }
  }

  // Create a new entity
  Future<int> createEntity(String title, double lat, double lon, File image) async {
    try {
      if (!isLoggedIn()) {
        throw Exception('Authentication required');
      }

      final bool connected = await isConnected();

      if (!connected) {
        // Create locally if offline
        final entity = Entity(
          title: title,
          lat: lat,
          lon: lon,
          // Local image path will be set later
        );

        // Save to local database with pending sync status
        return await _dbHelper.saveOfflineEntity(entity, 'create');
      }

      // Create multipart request
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));

      // Add auth headers
      request.headers.addAll(_getHeaders(isMultipart: true));

      // Add text fields
      request.fields['title'] = title;
      request.fields['lat'] = lat.toString();
      request.fields['lon'] = lon.toString();

      // Add the image file
      var imageStream = http.ByteStream(image.openRead());
      var length = await image.length();
      var multipartFile = http.MultipartFile(
          'image',
          imageStream,
          length,
          filename: image.path.split('/').last
      );
      request.files.add(multipartFile);

      // Send the request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data.containsKey('id')) {
          int newId = data['id'];

          // Create entity object
          final entity = Entity(
            id: newId,
            title: title,
            lat: lat,
            lon: lon,
            image: data['image'] ?? '',
          );

          // Cache in local database
          await _dbHelper.insertEntity(entity);

          // Save the image locally for offline use
          if (data['image'] != null) {
            final imageUrl = getImageUrl(data['image']);
            final localPath = await downloadImageForOffline(imageUrl, newId);
            if (localPath != null) {
              await _dbHelper.updateOfflineImage(newId, localPath);
            }
          }

          return newId;
        } else {
          throw Exception('Invalid response from server');
        }
      } else {
        throw Exception('Failed to create entity: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Create entity error: $e');
      throw Exception('Failed to create entity: $e');
    }
  }

  // Create entity without image (for web)
  Future<int> createEntityWithoutImage(String title, double lat, double lon) async {
    try {
      if (!isLoggedIn()) {
        throw Exception('Authentication required');
      }

      final bool connected = await isConnected();

      if (!connected) {
        // Create locally if offline
        final entity = Entity(
          title: title,
          lat: lat,
          lon: lon,
        );

        // Save to local database with pending sync status
        return await _dbHelper.saveOfflineEntity(entity, 'create');
      }

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: _getHeaders(),
        body: json.encode({
          'title': title,
          'lat': lat,
          'lon': lon,
        }),
      );

      if (response.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data.containsKey('id')) {
          int newId = data['id'];

          // Create entity object with placeholder image
          final entity = Entity(
            id: newId,
            title: title,
            lat: lat,
            lon: lon,
            image: data['image'] ?? '',
          );

          // Cache in local database
          await _dbHelper.insertEntity(entity);

          return newId;
        } else {
          throw Exception('Invalid response from server');
        }
      } else {
        throw Exception('Failed to create entity: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Create entity error: $e');
      throw Exception('Failed to create entity: $e');
    }
  }

  // Update an existing entity
  Future<bool> updateEntity(int id, String title, double lat, double lon, [File? image]) async {
    try {
      if (!isLoggedIn()) {
        throw Exception('Authentication required');
      }

      final bool connected = await isConnected();

      if (!connected) {
        // Update locally if offline
        final entity = Entity(
          id: id,
          title: title,
          lat: lat,
          lon: lon,
          // Keep existing image
        );

        // Save to local database with pending sync status
        await _dbHelper.saveOfflineEntity(entity, 'update');
        return true;
      }

      if (image != null) {
        // Multipart update request with new image
        var request = http.MultipartRequest('PUT', Uri.parse('$apiUrl$id/'));

        // Add auth headers
        request.headers.addAll(_getHeaders(isMultipart: true));

        // Add text fields
        request.fields['title'] = title;
        request.fields['lat'] = lat.toString();
        request.fields['lon'] = lon.toString();

        // Add the image file
        var imageStream = http.ByteStream(image.openRead());
        var length = await image.length();
        var multipartFile = http.MultipartFile(
            'image',
            imageStream,
            length,
            filename: image.path.split('/').last
        );
        request.files.add(multipartFile);

        // Send the request
        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final entity = Entity(
            id: id,
            title: title,
            lat: lat,
            lon: lon,
            image: data['image'] ?? '',
          );

          // Update in local cache
          await _dbHelper.updateEntity(entity);

          // Update local image
          if (data['image'] != null) {
            final imageUrl = getImageUrl(data['image']);
            final localPath = await downloadImageForOffline(imageUrl, id);
            if (localPath != null) {
              await _dbHelper.updateOfflineImage(id, localPath);
            }
          }

          return true;
        } else {
          throw Exception('Failed to update entity: ${response.statusCode} - ${response.body}');
        }
      } else {
        // Regular PUT request without image
        final response = await http.put(
          Uri.parse('$apiUrl$id/'),
          headers: _getHeaders(),
          body: json.encode({
            'title': title,
            'lat': lat,
            'lon': lon,
          }),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final entity = Entity(
            id: id,
            title: title,
            lat: lat,
            lon: lon,
            image: data['image'] ?? '',
          );

          // Update in local cache
          await _dbHelper.updateEntity(entity);

          return true;
        } else {
          throw Exception('Failed to update entity: ${response.statusCode} - ${response.body}');
        }
      }
    } catch (e) {
      print('Update entity error: $e');
      throw Exception('Failed to update entity: $e');
    }
  }

  // Delete an entity
  Future<bool> deleteEntity(int id) async {
    try {
      if (!isLoggedIn()) {
        throw Exception('Authentication required');
      }

      final bool connected = await isConnected();

      if (!connected) {
        // Delete locally if offline
        await _dbHelper.deleteEntity(id);
        return true;
      }

      final response = await http.delete(
        Uri.parse('$apiUrl$id/'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 204) {
        // Delete from local cache
        await _dbHelper.deleteEntity(id);
        return true;
      } else {
        throw Exception('Failed to delete entity: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Delete entity error: $e');
      throw Exception('Failed to delete entity: $e');
    }
  }

  // Get location info from Geoapify
  Future<Map<String, dynamic>> getLocationInfo(double lat, double lon) async {
    try {
      final bool connected = await isConnected();

      if (!connected) {
        return {}; // Return empty object if offline
      }

      // API Key for Geoapify
      const String apiKey = 'e7ce92dfdb12441ea2da31022f2e963e';
      final response = await http.get(
        Uri.parse('https://api.geoapify.com/v1/geocode/reverse?lat=$lat&lon=$lon&apiKey=$apiKey'),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {};
      }
    } catch (e) {
      print('Error getting location info: $e');
      return {};
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

    // Add the base URL
    return '$imageBaseUrl$imagePath';
  }

  // Download an image for offline use
  Future<String?> downloadImageForOffline(String imageUrl, int entityId) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));

      if (response.statusCode == 200) {
        // Get the app's documents directory
        final dir = await getApplicationDocumentsDirectory();
        final imageName = 'entity_${entityId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final imagePath = '${dir.path}/$imageName';

        // Write the image to disk
        final file = File(imagePath);
        await file.writeAsBytes(response.bodyBytes);

        return imagePath;
      }
      return null;
    } catch (e) {
      print('Failed to download image: $e');
      return null;
    }
  }

  // Download all images for offline use
  Future<void> downloadAllImages() async {
    try {
      final entities = await _dbHelper.getEntities();
      await _dbHelper.downloadAllImagesForOffline(entities);
    } catch (e) {
      print('Error downloading all images: $e');
    }
  }

  // Get current username
  Future<String?> getCurrentUsername() async {
    return await _dbHelper.getUsername();
  }

  // Check if there are pending offline changes
  Future<bool> hasPendingChanges() async {
    final actions = await _dbHelper.getUnsyncedActions();
    return actions.isNotEmpty;
  }
}
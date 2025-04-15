import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http_parser/http_parser.dart';
import '../models/entity.dart';
import '../database/database_helper.dart';

class ApiService {
  // API URL - Using the specified URL
  static const String baseUrl = 'https://labs.anontech.info/cse489/t3';
  static const String apiUrl = '$baseUrl/api.php';

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

    print('API Service initialized, auth token: ${_authToken ?? "none"}');
  }

  // Check connectivity
  Future<bool> isConnected() async {
    if (kIsWeb) {
      // For web, we can't directly check connectivity status in the same way
      try {
        // Try to ping a reliable server as a connectivity check
        final response = await http.get(Uri.parse('https://www.google.com')).timeout(
          const Duration(seconds: 5),
          onTimeout: () => http.Response('Error', 408),
        );
        return response.statusCode == 200;
      } catch (e) {
        print('Connectivity check error: $e');
        return false;
      }
    } else {
      // For mobile platforms
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    }
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
      // In this example, we'll simulate login success since the actual API might not support auth
      _authToken = "sample_token_${username}_${DateTime.now().millisecondsSinceEpoch}";

      // Save token to shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(authTokenKey, _authToken!);

      // Save to local database
      await _dbHelper.saveUserAuth(username, _authToken!);

      return true;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  // Register a new user
  Future<bool> register(String username, String password, String email) async {
    try {
      // In this example, we'll simulate registration success
      _authToken = "sample_token_${username}_${DateTime.now().millisecondsSinceEpoch}";

      // Save token to shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(authTokenKey, _authToken!);

      // Save to local database
      await _dbHelper.saveUserAuth(username, _authToken!);

      return true;
    } catch (e) {
      print('Registration error: $e');
      return false;
    }
  }

  // Logout user
  Future<void> logout() async {
    try {
      _authToken = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(authTokenKey);
      await _dbHelper.clearAuthInfo();
    } catch (e) {
      print('Logout error: $e');
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
        print('Fetching entities from API: $apiUrl');
        // Make the GET request to the API
        final response = await http.get(
          Uri.parse(apiUrl),
        ).timeout(const Duration(seconds: 30));

        print('API Response: ${response.statusCode}');
        if (response.body.isNotEmpty) {
          print('API Response body sample: ${response.body.substring(0, min(200, response.body.length))}...');
        }

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);

          final List<Entity> entities = data.map((item) {
            // Map the API response to Entity object
            return Entity(
              id: item['id'],
              title: item['title'],
              lat: item['lat'] is String ? double.parse(item['lat']) : item['lat'],
              lon: item['lon'] is String ? double.parse(item['lon']) : item['lon'],
              image: item['image'],
              properties: null, // No properties in the API response
            );
          }).toList();

          print('Parsed ${entities.length} entities from API');

          // Cache entities in local database
          await _dbHelper.deleteAllEntities();
          for (var entity in entities) {
            await _dbHelper.insertEntity(entity);
          }

          return entities;
        } else {
          throw Exception('Failed to load entities: ${response.statusCode} - ${response.body}');
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
      print('Sending POST request to $apiUrl');
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      print('Create Entity Response: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final Map<String, dynamic> data = json.decode(response.body);

          if (data.containsKey('id')) {
            int newId = data['id'] is String ? int.parse(data['id']) : data['id'];

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

            return newId;
          } else {
            // If the response doesn't contain an ID but the status is OK,
            // we'll use a dummy ID for now
            final tempId = DateTime.now().millisecondsSinceEpoch;

            // Create entity object
            final entity = Entity(
              id: tempId,
              title: title,
              lat: lat,
              lon: lon,
              image: '',
            );

            // Cache in local database
            await _dbHelper.insertEntity(entity);

            return tempId;
          }
        } catch (e) {
          print('Error parsing response: $e');
          throw Exception('Invalid response from server: $e');
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

      // For web, we'll use FormData with direct http approach
      var uri = Uri.parse(apiUrl);
      var request = http.MultipartRequest('POST', uri);

      // Add form fields
      request.fields['title'] = title;
      request.fields['lat'] = lat.toString();
      request.fields['lon'] = lon.toString();

      // For debugging
      print('Sending request to $uri with fields: ${request.fields}');

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();

      print('Response code: ${response.statusCode}');
      print('Response body: $responseBody');

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          var data = json.decode(responseBody);
          if (data is Map && data.containsKey('id')) {
            var id = data['id'] is String ? int.parse(data['id']) : data['id'];

            // Create entity object
            final entity = Entity(
              id: id,
              title: title,
              lat: lat,
              lon: lon,
              image: data['image'] ?? '',
            );

            // Cache in local database
            await _dbHelper.insertEntity(entity);

            return id;
          }
        } catch (e) {
          print('Error parsing response: $e');
        }

        // If we can't parse the ID, return a temporary one
        var tempId = DateTime.now().millisecondsSinceEpoch;

        // Create entity object with temporary ID
        final entity = Entity(
          id: tempId,
          title: title,
          lat: lat,
          lon: lon,
          image: '',
        );

        // Cache in local database
        await _dbHelper.insertEntity(entity);

        return tempId;
      } else {
        throw Exception('Failed to create entity: ${response.statusCode} - $responseBody');
      }
    } catch (e) {
      print('Error in createEntityWithoutImage: $e');
      throw Exception('Failed to create entity: $e');
    }
  }

  // Create entity with bytes (for web)
  Future<int> createEntityWithBytes(String title, double lat, double lon, Uint8List imageBytes, String fileName) async {
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

      // For web, use a MultipartRequest with byte data
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));

      // Add text fields
      request.fields['title'] = title;
      request.fields['lat'] = lat.toString();
      request.fields['lon'] = lon.toString();

      // Add the image file from bytes
      var multipartFile = http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: fileName,
        contentType: MediaType('image', 'jpeg'), // Assuming JPEG format, adjust if needed
      );

      request.files.add(multipartFile);

      // Send the request
      print('Sending POST request to $apiUrl with image bytes');
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      print('Create Entity Response: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final Map<String, dynamic> data = json.decode(response.body);

          if (data.containsKey('id')) {
            int newId = data['id'] is String ? int.parse(data['id']) : data['id'];

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

            return newId;
          }
        } catch (e) {
          print('Error parsing response: $e');
        }

        // Use a temporary ID if we can't get one from the response
        final tempId = DateTime.now().millisecondsSinceEpoch;
        final entity = Entity(
          id: tempId,
          title: title,
          lat: lat,
          lon: lon,
          image: '',
        );
        await _dbHelper.insertEntity(entity);
        return tempId;
      } else {
        throw Exception('Failed to create entity: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Create entity with bytes error: $e');
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

      // Create a multipart request for the update
      var request = http.MultipartRequest('PUT', Uri.parse(apiUrl));

      // Add fields
      request.fields['id'] = id.toString();
      request.fields['title'] = title;
      request.fields['lat'] = lat.toString();
      request.fields['lon'] = lon.toString();

      // Add image if provided
      if (image != null) {
        var imageStream = http.ByteStream(image.openRead());
        var length = await image.length();
        var multipartFile = http.MultipartFile(
            'image',
            imageStream,
            length,
            filename: image.path.split('/').last
        );

        request.files.add(multipartFile);
      }

      // Send the request
      print('Sending PUT request to $apiUrl');
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      print('Update Entity Response: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        // Update local cache
        final entity = Entity(
          id: id,
          title: title,
          lat: lat,
          lon: lon,
          image: null, // We don't know the new image path from response
        );

        await _dbHelper.updateEntity(entity);
        return true;
      } else {
        throw Exception('Failed to update entity: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Update entity error: $e');
      throw Exception('Failed to update entity: $e');
    }
  }

  // Update entity with bytes (for web)
  Future<bool> updateEntityWithBytes(int id, String title, double lat, double lon, Uint8List? imageBytes, String fileName) async {
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
        );

        // Save to local database with pending sync status
        await _dbHelper.saveOfflineEntity(entity, 'update');
        return true;
      }

      // Create multipart request
      var request = http.MultipartRequest('PUT', Uri.parse(apiUrl));

      // Add text fields
      request.fields['id'] = id.toString();
      request.fields['title'] = title;
      request.fields['lat'] = lat.toString();
      request.fields['lon'] = lon.toString();

      // Add image bytes if provided
      if (imageBytes != null) {
        var multipartFile = http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: fileName,
          contentType: MediaType('image', 'jpeg'), // Adjust if needed
        );

        request.files.add(multipartFile);
      }

      // Send the request
      print('Sending PUT request to $apiUrl with ID $id');
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      print('Update Entity Response: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        // Update the local entity
        final entity = Entity(
          id: id,
          title: title,
          lat: lat,
          lon: lon,
          image: null, // Unknown from response
        );

        await _dbHelper.updateEntity(entity);
        return true;
      } else {
        throw Exception('Failed to update entity: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Update entity with bytes error: $e');
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

      // For DELETE request with ID, we'll use a custom solution since standard DELETE may not support body
      var request = http.Request('DELETE', Uri.parse(apiUrl));
      request.headers['Content-Type'] = 'application/x-www-form-urlencoded';
      request.bodyFields = {'id': id.toString()};

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      print('Delete Entity Response: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 204) {
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
    if (imagePath.startsWith('/')) {
      return '$baseUrl$imagePath';
    } else {
      return '$baseUrl/$imagePath';
    }
  }

  // Download an image for offline use
  Future<String?> downloadImageForOffline(String imageUrl, int entityId) async {
    if (kIsWeb) {
      print('Downloading images for offline use is not supported on web platform');
      return null;
    }

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
    if (kIsWeb) {
      print('Downloading all images for offline use is not supported on web platform');
      return;
    }

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

            // Create multipart request
            var request = http.MultipartRequest('POST', Uri.parse(apiUrl));

            // Add text fields
            request.fields['title'] = entityData['title'];
            request.fields['lat'] = entityData['lat'].toString();
            request.fields['lon'] = entityData['lon'].toString();

            // Send the request
            var streamedResponse = await request.send();
            var response = await http.Response.fromStream(streamedResponse);

            if (response.statusCode == 200 || response.statusCode == 201) {
              successfulSyncs.add(action['id']);

              try {
                final Map<String, dynamic> responseData = json.decode(response.body);

                if (responseData.containsKey('id')) {
                  // Get the temporary entity
                  final tempEntity = await _dbHelper.getEntityById(entityId);

                  if (tempEntity != null) {
                    // Delete the temp entity
                    await _dbHelper.deleteEntity(entityId);

                    // Create a new entity with the real ID
                    final newId = responseData['id'] is String ?
                    int.parse(responseData['id']) :
                    responseData['id'];

                    final newEntity = Entity(
                      id: newId,
                      title: tempEntity.title,
                      lat: tempEntity.lat,
                      lon: tempEntity.lon,
                      image: responseData['image'],
                      properties: tempEntity.properties,
                    );

                    await _dbHelper.insertEntity(newEntity);
                  }
                }
              } catch (e) {
                print('Error processing create response: $e');
              }
            }
          } else if (actionType == 'update' && entityDataJson != null) {
            final entityData = json.decode(entityDataJson);

            // Create multipart request
            var request = http.MultipartRequest('PUT', Uri.parse(apiUrl));

            // Add fields including ID for update
            request.fields['id'] = entityId.toString();
            request.fields['title'] = entityData['title'];
            request.fields['lat'] = entityData['lat'].toString();
            request.fields['lon'] = entityData['lon'].toString();

            // Send the request
            var streamedResponse = await request.send();
            var response = await http.Response.fromStream(streamedResponse);

            if (response.statusCode == 200) {
              successfulSyncs.add(action['id']);

              // Update the local entity status
              final entity = await _dbHelper.getEntityById(entityId);
              if (entity != null) {
                await _dbHelper.updateEntity(entity);
              }
            }
          } else if (actionType == 'delete') {
            // For DELETE request with ID
            var request = http.Request('DELETE', Uri.parse(apiUrl));
            request.headers['Content-Type'] = 'application/x-www-form-urlencoded';
            request.bodyFields = {'id': entityId.toString()};

            var streamedResponse = await request.send();
            var response = await http.Response.fromStream(streamedResponse);

            if (response.statusCode == 200 || response.statusCode == 204) {
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

  // Helper function to get min of two integers
  int min(int a, int b) {
    return a < b ? a : b;
  }
}
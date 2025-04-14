import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import '../models/entity.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;

    // Initialize the database
    _database = await _initDatabase();
    return _database!;
  }

  // Create and open the database
  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'geo_bangladesh.db');

    return await openDatabase(
      path,
      version: 2,  // Increased version for schema update
      onCreate: (Database db, int version) async {
        // Create entity table
        await db.execute('''
          CREATE TABLE entities (
            id INTEGER PRIMARY KEY,
            title TEXT NOT NULL,
            lat REAL NOT NULL,
            lon REAL NOT NULL,
            image TEXT,
            properties TEXT,
            offline_image_path TEXT,
            last_updated INTEGER,
            sync_status TEXT DEFAULT 'synced'
          )
        ''');

        // Create user table for auth
        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL UNIQUE,
            auth_token TEXT,
            last_login INTEGER
          )
        ''');

        // Create offline actions queue table
        await db.execute('''
          CREATE TABLE offline_actions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            action_type TEXT NOT NULL,
            entity_id INTEGER,
            entity_data TEXT,
            created_at INTEGER NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Add sync_status column if upgrading from version 1
          await db.execute('ALTER TABLE entities ADD COLUMN sync_status TEXT DEFAULT "synced"');

          // Create offline actions queue table if it doesn't exist
          await db.execute('''
            CREATE TABLE IF NOT EXISTS offline_actions (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              action_type TEXT NOT NULL,
              entity_id INTEGER,
              entity_data TEXT,
              created_at INTEGER NOT NULL
            )
          ''');
        }
      },
    );
  }

  // Insert a new entity into the database
  Future<int> insertEntity(Entity entity) async {
    final db = await database;

    // Convert properties to JSON string if available
    String? propertiesJson;
    if (entity.properties != null) {
      propertiesJson = json.encode(entity.properties);
    }

    // Insert the entity
    return await db.insert(
      'entities',
      {
        'id': entity.id,
        'title': entity.title,
        'lat': entity.lat,
        'lon': entity.lon,
        'image': entity.image,
        'properties': propertiesJson,
        'last_updated': DateTime.now().millisecondsSinceEpoch,
        'sync_status': 'synced'
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Update an existing entity
  Future<int> updateEntity(Entity entity) async {
    final db = await database;

    // Convert properties to JSON string if available
    String? propertiesJson;
    if (entity.properties != null) {
      propertiesJson = json.encode(entity.properties);
    }

    // Update the entity
    return await db.update(
      'entities',
      {
        'title': entity.title,
        'lat': entity.lat,
        'lon': entity.lon,
        'image': entity.image ?? '', // Use empty string if image is null
        'properties': propertiesJson,
        'last_updated': DateTime.now().millisecondsSinceEpoch,
        'sync_status': 'synced'
      },
      where: 'id = ?',
      whereArgs: [entity.id],
    );
  }

  // Create or update entity while offline
  Future<int> saveOfflineEntity(Entity entity, String action) async {
    final db = await database;

    if (action == 'create') {
      // For new entities in offline mode, use temporary negative ID
      // These will be replaced with real IDs when synced
      int tempId = -DateTime.now().millisecondsSinceEpoch;

      // Convert properties to JSON string if available
      String? propertiesJson;
      if (entity.properties != null) {
        propertiesJson = json.encode(entity.properties);
      }

      // Insert with temporary ID and mark as unsynced
      await db.insert(
        'entities',
        {
          'id': tempId,
          'title': entity.title,
          'lat': entity.lat,
          'lon': entity.lon,
          'image': entity.image,
          'properties': propertiesJson,
          'last_updated': DateTime.now().millisecondsSinceEpoch,
          'sync_status': 'unsynced'
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Add to offline actions queue
      await db.insert(
          'offline_actions',
          {
            'action_type': 'create',
            'entity_id': tempId,
            'entity_data': json.encode(entity.toJson()),
            'created_at': DateTime.now().millisecondsSinceEpoch
          }
      );

      return tempId;
    } else if (action == 'update') {
      // Convert properties to JSON string if available
      String? propertiesJson;
      if (entity.properties != null) {
        propertiesJson = json.encode(entity.properties);
      }

      // Update and mark as unsynced
      await db.update(
        'entities',
        {
          'title': entity.title,
          'lat': entity.lat,
          'lon': entity.lon,
          'image': entity.image ?? '', // Use empty string if image is null
          'properties': propertiesJson,
          'last_updated': DateTime.now().millisecondsSinceEpoch,
          'sync_status': 'unsynced'
        },
        where: 'id = ?',
        whereArgs: [entity.id],
      );

      // Add to offline actions queue
      await db.insert(
          'offline_actions',
          {
            'action_type': 'update',
            'entity_id': entity.id,
            'entity_data': json.encode(entity.toJson()),
            'created_at': DateTime.now().millisecondsSinceEpoch
          }
      );

      return entity.id!;
    }

    return -1;
  }

  // Delete an entity
  Future<int> deleteEntity(int id) async {
    final db = await database;

    // Add to offline actions queue if it's a real entity (not temporary)
    if (id > 0) {
      await db.insert(
          'offline_actions',
          {
            'action_type': 'delete',
            'entity_id': id,
            'entity_data': null,
            'created_at': DateTime.now().millisecondsSinceEpoch
          }
      );
    }

    return await db.delete(
      'entities',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Delete all entities
  Future<int> deleteAllEntities() async {
    final db = await database;
    return await db.delete('entities');
  }

  // Get all entities
  Future<List<Entity>> getEntities() async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query('entities');

    return List.generate(maps.length, (i) {
      Map<String, dynamic>? properties;

      if (maps[i]['properties'] != null) {
        try {
          properties = json.decode(maps[i]['properties']);
        } catch (e) {
          print('Error parsing properties: $e');
        }
      }

      return Entity(
        id: maps[i]['id'],
        title: maps[i]['title'],
        lat: maps[i]['lat'],
        lon: maps[i]['lon'],
        image: maps[i]['image'],
        properties: properties,
      );
    });
  }

  // Get unsynced entities
  Future<List<Map<String, dynamic>>> getUnsyncedActions() async {
    final db = await database;

    return await db.query(
      'offline_actions',
      orderBy: 'created_at ASC',
    );
  }

  // Clear synced actions
  Future<int> clearSyncedActions(List<int> actionIds) async {
    final db = await database;

    return await db.delete(
      'offline_actions',
      where: 'id IN (${actionIds.map((_) => '?').join(',')})',
      whereArgs: actionIds,
    );
  }

  // Get a specific entity by ID
  Future<Entity?> getEntityById(int id) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'entities',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      Map<String, dynamic>? properties;

      if (maps[0]['properties'] != null) {
        try {
          properties = json.decode(maps[0]['properties']);
        } catch (e) {
          print('Error parsing properties: $e');
        }
      }

      return Entity(
        id: maps[0]['id'],
        title: maps[0]['title'],
        lat: maps[0]['lat'],
        lon: maps[0]['lon'],
        image: maps[0]['image'],
        properties: properties,
      );
    }

    return null;
  }

  // Update offline image path
  Future<int> updateOfflineImage(int entityId, String path) async {
    final db = await database;

    return await db.update(
      'entities',
      {'offline_image_path': path},
      where: 'id = ?',
      whereArgs: [entityId],
    );
  }

  // Get offline image path
  Future<String?> getOfflineImagePath(int entityId) async {
    final db = await database;

    final List<Map<String, dynamic>> result = await db.query(
      'entities',
      columns: ['offline_image_path'],
      where: 'id = ?',
      whereArgs: [entityId],
    );

    if (result.isNotEmpty && result[0]['offline_image_path'] != null) {
      return result[0]['offline_image_path'];
    }

    return null;
  }

  // Download and save all images for offline use
  Future<void> downloadAllImagesForOffline(List<Entity> entities) async {
    final directory = await getApplicationDocumentsDirectory();

    for (var entity in entities) {
      if (entity.id != null && entity.image != null && entity.image!.isNotEmpty) {
        try {
          // Skip if already downloaded
          final existingPath = await getOfflineImagePath(entity.id!);
          if (existingPath != null && File(existingPath).existsSync()) {
            continue;
          }

          // Get the image URL
          final imageUrl = entity.image!.startsWith('http')
              ? entity.image!
              : 'https://geo-bangladesh-api.onrender.com${entity.image}';

          // Create HttpClient
          final httpClient = HttpClient();
          final request = await httpClient.getUrl(Uri.parse(imageUrl));
          final response = await request.close();

          if (response.statusCode == 200) {
            final imageName = 'entity_${entity.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
            final imagePath = '${directory.path}/$imageName';

            // Save the image to disk
            final file = File(imagePath);
            await response.pipe(file.openWrite());

            // Update database with offline image path
            await updateOfflineImage(entity.id!, imagePath);
          }

          httpClient.close();
        } catch (e) {
          print('Failed to download image for entity ${entity.id}: $e');
        }
      }
    }
  }

  // Save user auth info
  Future<int> saveUserAuth(String username, String token) async {
    final db = await database;

    // First delete any existing users
    await db.delete('users');

    // Then insert the new user
    return await db.insert(
      'users',
      {
        'username': username,
        'auth_token': token,
        'last_login': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  // Get the stored auth token
  Future<String?> getAuthToken() async {
    final db = await database;

    final List<Map<String, dynamic>> result = await db.query('users');

    if (result.isNotEmpty) {
      return result[0]['auth_token'];
    }

    return null;
  }

  // Get the current logged in username
  Future<String?> getUsername() async {
    final db = await database;

    final List<Map<String, dynamic>> result = await db.query('users');

    if (result.isNotEmpty) {
      return result[0]['username'];
    }

    return null;
  }

  // Clear auth info on logout
  Future<int> clearAuthInfo() async {
    final db = await database;
    return await db.delete('users');
  }
}
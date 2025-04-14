import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/entity.dart';
import '../services/api_service.dart';
import '../main.dart';
import 'entity_form.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;

class EntityListScreen extends StatefulWidget {
  const EntityListScreen({Key? key}) : super(key: key);

  @override
  _EntityListScreenState createState() => _EntityListScreenState();
}

class _EntityListScreenState extends State<EntityListScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchEntities();
  }

  // Fetch entities from storage
  Future<void> _fetchEntities() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final entities = await _apiService.getEntities();

      // Update the provider
      Provider.of<EntityProvider>(context, listen: false).setEntities(entities);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load entities: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _fetchEntities,
                child: const Text('Retry'),
              ),
            ],
          ),
        )
            : Consumer<EntityProvider>(
        builder: (context, provider, child) {
      final entities = provider.entities;

      if (entities.isEmpty) {
        return const Center(
          child: Text(
            'No entities found.\nCreate a new entity using the Form option.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        );
      }

      return RefreshIndicator(
          onRefresh: _fetchEntities,
          child: ListView.builder(
          itemCount: entities.length,
          itemBuilder: (context, index) {
        final entity = entities[index];
        return Dismissible(
            key: Key(entity.id.toString()),
    background: Container(
    color: Colors.red,
    alignment: Alignment.centerRight,
    padding: const EdgeInsets.only(right: 20),
    child: const Icon(Icons.delete, color: Colors.white),
    ),
    direction: DismissDirection.endToStart,
    confirmDismiss: (_) async {
    return await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
    title: const Text('Confirm Delete'),
    content: Text('Are you sure you want to delete "${entity.title}"?'),
    actions: [
    TextButton(
    onPressed: () => Navigator.pop(context, false),
    child: const Text('Cancel'),
    ),
    TextButton(
    onPressed: () => Navigator.pop(context, true),
    child: const Text('Delete', style: TextStyle(color: Colors.red)),
    ),
    ],
    ),
    );
    },
    onDismissed: (_) async {
    if (entity.id != null) {
    await _apiService.deleteEntity(entity.id!);
    provider.deleteEntity(entity.id!);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${entity.title} deleted')),
    );
    }
    },
          child: Card(
            margin: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            child: ListTile(
              leading: entity.image != null && entity.image!.isNotEmpty
                  ? ClipOval(
                child: CachedNetworkImage(
                  imageUrl: ApiService.getImageUrl(entity.image),
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const CircularProgressIndicator(),
                  // Improved error handling - silent failure with fallback UI
                  errorWidget: (context, url, error) => const CircleAvatar(
                    backgroundColor: Colors.grey,
                    child: Icon(Icons.location_on, color: Colors.white),
                  ),
                ),
              )
                  : const CircleAvatar(
                backgroundColor: Colors.grey,
                child: Icon(Icons.location_on, color: Colors.white),
              ),




              title: Text(entity.title),
              subtitle: Text(
                'Lat: ${entity.lat.toStringAsFixed(6)}, Lon: ${entity.lon.toStringAsFixed(6)}',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  _navigateToEditEntity(entity);
                },
              ),
              onTap: () {
                _showEntityDetails(entity);
              },
            ),
          ),
        );
          },
          ),
      );
        },
        ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchEntities,
        tooltip: 'Refresh',
        child: const Icon(Icons.refresh),
      ),
    );
  }

  // Navigate to edit entity screen
  void _navigateToEditEntity(Entity entity) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EntityFormScreen(entityToEdit: entity),
      ),
    ).then((_) {
      // Refresh entities when returning from edit screen
      _fetchEntities();
    });
  }

  // Show entity details in a dialog
  void _showEntityDetails(Entity entity) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(entity.title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (entity.image != null && entity.image!.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _showFullImage(entity.title, entity.image!);
                    },
                    child: Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: NetworkImage(ApiService.getImageUrl(entity.image)),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Text('Latitude: ${entity.lat.toStringAsFixed(6)}'),
                Text('Longitude: ${entity.lon.toStringAsFixed(6)}'),

                // Display additional properties if available
                if (entity.properties != null && entity.properties!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Additional Information:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (entity.properties!['formatted'] != null)
                    Text('Address: ${entity.properties!['formatted']}'),
                  if (entity.properties!['country'] != null)
                    Text('Country: ${entity.properties!['country']}'),
                  if (entity.properties!['city'] != null)
                    Text('City: ${entity.properties!['city']}'),
                ],

                const SizedBox(height: 8),
                if (entity.image != null && entity.image!.isNotEmpty)
                  const Text(
                    'Tap on the image to view full-screen',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _navigateToEditEntity(entity);
              },
              child: const Text('Edit'),
            ),
            TextButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Confirm Delete'),
                    content: Text('Are you sure you want to delete "${entity.title}"?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );

                if (confirm == true && entity.id != null) {
                  Navigator.pop(context);
                  await _apiService.deleteEntity(entity.id!);
                  Provider.of<EntityProvider>(context, listen: false).deleteEntity(entity.id!);
                  _fetchEntities();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${entity.title} deleted')),
                  );
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  // Show full-screen image
  void _showFullImage(String title, String imagePath) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(title),
          ),
          body: Center(
            child: CachedNetworkImage(
              imageUrl: ApiService.getImageUrl(imagePath),
              placeholder: (context, url) => const Center(
                child: CircularProgressIndicator(),
              ),
              // Improved error handling with more user-friendly message
              errorWidget: (context, url, error) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'Image unavailable',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }




}






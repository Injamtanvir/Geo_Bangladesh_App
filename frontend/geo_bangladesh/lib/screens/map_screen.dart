import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/entity.dart';
import '../services/api_service.dart';
import '../main.dart';
import 'entity_form.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _controller;
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String _errorMessage = '';
  final Set<Marker> _markers = {};
  bool _isMapReady = false;

  // Bangladesh center coordinates
  static const LatLng _bangladesh = LatLng(23.6850, 90.3563);

  @override
  void initState() {
    super.initState();
    _fetchEntities();
  }

  // Fetch entities
  Future<void> _fetchEntities() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      print('Fetching entities');
      final entities = await _apiService.getEntities();
      print('Fetched ${entities.length} entities');

      // Update the provider
      if (mounted) {
        Provider.of<EntityProvider>(context, listen: false).setEntities(entities);

        // Create markers for each entity
        _createMarkers(entities);

        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching entities: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load entities: $e';
        });
      }
    }
  }

  // Create map markers from entities
  void _createMarkers(List<Entity> entities) {
    print('Creating markers for ${entities.length} entities');
    Set<Marker> markers = {};

    for (var entity in entities) {
      // Skip if ID is null
      if (entity.id == null) {
        print('Skipping entity with null ID');
        continue;
      }

      print('Creating marker for entity ${entity.id}: ${entity.title}');

      final markerId = MarkerId(entity.id.toString());
      final marker = Marker(
        markerId: markerId,
        position: LatLng(entity.lat, entity.lon),
        infoWindow: InfoWindow(
          title: entity.title,
          snippet: 'Tap for details',
        ),
        onTap: () {
          print('Marker tapped: ${entity.title}');
          _showEntityDetails(entity);
        },
      );

      markers.add(marker);
    }

    print('Created ${markers.length} markers');

    if (mounted) {
      setState(() {
        _markers.clear();
        _markers.addAll(markers);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage,
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
          : _buildMap(),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchEntities,
        tooltip: 'Refresh',
        child: const Icon(Icons.refresh),
      ),
    );
  }

  // Build the map with alternative for web if needed
  Widget _buildMap() {
    // Check if we are on web and need to show a warning about API key
    if (kIsWeb && !_isMapReady) {
      return Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _bangladesh,
              zoom: 7,
            ),
            markers: _markers,
            onMapCreated: (GoogleMapController controller) {
              _controller = controller;
              setState(() {
                _isMapReady = true;
              });
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          // Overlay with instructions if map doesn't load on web
          Positioned.fill(
            child: Container(
              color: Colors.white.withOpacity(0.8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.map, size: 64, color: Colors.green),
                  const SizedBox(height: 16),
                  const Text(
                    'Map Loading',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'If the map doesn\'t appear, you might need to setup a Google Maps API key in web/index.html',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'For web apps, the Google Maps API key needs to be properly configured and have the correct HTTP referrers',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isMapReady = true; // Remove overlay to try viewing the map
                      });
                    },
                    child: const Text('Try Viewing Map Anyway'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    } else {
      // Regular map for mobile or web when ready
      return GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: _bangladesh,
          zoom: 7,
        ),
        markers: _markers,
        onMapCreated: (GoogleMapController controller) {
          _controller = controller;
        },
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
      );
    }
  }

  // Show entity details in a modal bottom sheet
  void _showEntityDetails(Entity entity) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entity.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text('Latitude: ${entity.lat.toStringAsFixed(6)}'),
              Text('Longitude: ${entity.lon.toStringAsFixed(6)}'),
              const SizedBox(height: 16),
              if (entity.image != null && entity.image!.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _showFullImage(entity.title, entity.image!);
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: ApiService.getImageUrl(entity.image),
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      errorWidget: (context, url, error) => const Icon(Icons.error),
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'Tap on the image to enlarge',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
              ),

              // Display additional properties if available
              if (entity.properties != null && entity.properties!.isNotEmpty)
                ..._buildAdditionalProperties(entity.properties!),

              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EntityFormScreen(entityToEdit: entity),
                        ),
                      );
                    },
                    child: const Text('Edit'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      // Show confirmation dialog
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
                        await _apiService.deleteEntity(entity.id!);
                        Provider.of<EntityProvider>(context, listen: false).deleteEntity(entity.id!);
                        _fetchEntities(); // Refresh markers
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Entity deleted successfully')),
                        );
                      }
                    },
                    child: const Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Build widgets for additional properties
  List<Widget> _buildAdditionalProperties(Map<String, dynamic> properties) {
    List<Widget> widgets = [];

    widgets.add(
      const SizedBox(height: 16),
    );

    widgets.add(
      const Text(
        'Additional Information:',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    // Add properties safely
    if (properties.containsKey('formatted') && properties['formatted'] != null) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text('Address: ${properties['formatted']}'),
        ),
      );
    }

    if (properties.containsKey('categories') && properties['categories'] != null) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text('Categories: ${properties['categories']}'),
        ),
      );
    }

    if (properties.containsKey('country') && properties['country'] != null) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text('Country: ${properties['country']}'),
        ),
      );
    }

    if (properties.containsKey('city') && properties['city'] != null) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text('City: ${properties['city']}'),
        ),
      );
    }

    return widgets;
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
            child: InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4,
              child: CachedNetworkImage(
                imageUrl: ApiService.getImageUrl(imagePath),
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(),
                ),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (_controller != null) {
      _controller!.dispose();
    }
    super.dispose();
  }
}
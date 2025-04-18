import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/entity.dart';
import '../services/api_service.dart';
import '../utils/image_utils.dart';
import '../main.dart';
import 'package:permission_handler/permission_handler.dart';

class EntityFormScreen extends StatefulWidget {
  final Entity? entityToEdit;

  const EntityFormScreen({Key? key, this.entityToEdit}) : super(key: key);

  @override
  _EntityFormScreenState createState() => _EntityFormScreenState();
}

class _EntityFormScreenState extends State<EntityFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _latController = TextEditingController();
  final _lonController = TextEditingController();

  // Use XFile instead of File for cross-platform compatibility
  XFile? _selectedImage;
  Uint8List? _webImageBytes;

  final ApiService _apiService = ApiService();

  bool _isSubmitting = false;
  String? _errorMessage;
  bool _isEditMode = false;
  int? _editEntityId;
  bool _isLoggedIn = false;
  bool _isOfflineMode = false;

  // Location data
  Map<String, dynamic>? _locationInfo;
  bool _isLoadingLocationInfo = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
    _checkConnectivity();
    _initForm();
  }

  // Check if user is logged in
  Future<void> _checkAuthStatus() async {
    await _apiService.initialize();

    setState(() {
      _isLoggedIn = _apiService.isLoggedIn();
    });

    if (!_isLoggedIn) {
      // Show warning if not logged in
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be logged in to create or edit entities'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
      });
    }
  }

  // Check for internet connectivity
  Future<void> _checkConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();

    setState(() {
      _isOfflineMode = connectivityResult == ConnectivityResult.none;
    });

    // Listen for connectivity changes
    Connectivity().onConnectivityChanged.listen((result) {
      setState(() {
        _isOfflineMode = result == ConnectivityResult.none;
      });

      if (result == ConnectivityResult.none) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You are offline. Changes will be saved locally and synced when online.'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You are back online.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  // Initialize form with entity data if in edit mode
  void _initForm() async {
    if (widget.entityToEdit != null) {
      setState(() {
        _isEditMode = true;
        _editEntityId = widget.entityToEdit!.id;
        _titleController.text = widget.entityToEdit!.title;
        _latController.text = widget.entityToEdit!.lat.toString();
        _lonController.text = widget.entityToEdit!.lon.toString();
        _locationInfo = widget.entityToEdit!.properties;
      });
    } else {
      // Get current location for new entity
      _getCurrentLocation();
    }
  }

  // Get current GPS coordinates
  Future<void> _getCurrentLocation() async {
    try {
      // Check if running on web
      if (kIsWeb) {
        try {
          // Web-specific location handling
          Position position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high
          );

          setState(() {
            _latController.text = position.latitude.toString();
            _lonController.text = position.longitude.toString();
          });

          // Get location info from Geoapify if online
          if (!_isOfflineMode) {
            _getLocationInfo(position.latitude, position.longitude);
          }
        } catch (e) {
          // Default to Bangladesh center coordinates if location access fails
          setState(() {
            _latController.text = "23.6850";
            _lonController.text = "90.3563";
            _errorMessage = 'Using default location. Error: $e';
          });
        }
      } else {
        // Check location permissions for mobile
        LocationPermission permission = await Geolocator.checkPermission();

        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();

          if (permission == LocationPermission.denied) {
            setState(() {
              _errorMessage = 'Location permissions are denied';
              // Default to Bangladesh center
              _latController.text = "23.6850";
              _lonController.text = "90.3563";
            });
            return;
          }
        }

        if (permission == LocationPermission.deniedForever) {
          setState(() {
            _errorMessage = 'Location permissions are permanently denied, we cannot request permissions.';
            // Default to Bangladesh center
            _latController.text = "23.6850";
            _lonController.text = "90.3563";
          });
          return;
        }

        // Get current position
        Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high
        );

        setState(() {
          _latController.text = position.latitude.toString();
          _lonController.text = position.longitude.toString();
        });

        // Get location info from Geoapify if online
        if (!_isOfflineMode) {
          _getLocationInfo(position.latitude, position.longitude);
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to get current location: $e';
        // Default to Bangladesh center
        _latController.text = "23.6850";
        _lonController.text = "90.3563";
      });
    }
  }

  // Get location info from Geoapify
  Future<void> _getLocationInfo(double lat, double lon) async {
    try {
      if (_isOfflineMode) {
        return; // Skip if offline
      }

      setState(() {
        _isLoadingLocationInfo = true;
      });

      final locationData = await _apiService.getLocationInfo(lat, lon);

      if (mounted) {
        setState(() {
          _locationInfo = locationData;
          _isLoadingLocationInfo = false;

          // Auto-suggest a title based on location
          if (_titleController.text.isEmpty &&
              locationData['features'] != null &&
              locationData['features'].isNotEmpty) {
            final feature = locationData['features'][0];

            if (feature['properties'] != null) {
              final props = feature['properties'];
              String title = '';

              if (props['name'] != null && props['name'].toString().isNotEmpty) {
                title = props['name'];
              } else if (props['street'] != null) {
                title = props['street'];

                if (props['housenumber'] != null) {
                  title += ' ${props['housenumber']}';
                }
              } else if (props['city'] != null) {
                title = 'Location in ${props['city']}';
              } else if (props['country'] != null) {
                title = 'Location in ${props['country']}';
              } else {
                title = 'Location at ${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}';
              }

              _titleController.text = title;
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingLocationInfo = false;
        });
      }

      print('Failed to get location info: $e');
    }
  }

  // Pick image from gallery
  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();

      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 600,
        imageQuality: 85,
      );

      if (image != null) {
        if (kIsWeb) {
          // For web, we need to load the image as bytes
          final bytes = await image.readAsBytes();

          setState(() {
            _selectedImage = image;
            _webImageBytes = bytes;
          });
        } else {
          setState(() {
            _selectedImage = image;
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to pick image: $e';
      });
    }
  }

  Future<void> _takePhoto() async {
    try {
      final ImagePicker picker = ImagePicker();

      if (kIsWeb) {
        // Web does not support camera through browser, redirect to gallery
        await _pickImage();
        return;
      }

      // First check camera permission on mobile
      if (Platform.isAndroid || Platform.isIOS) {
        // Try to get camera permission explicitly
        final status = await Permission.camera.request();

        if (status.isDenied || status.isPermanentlyDenied) {
          setState(() {
            _errorMessage = 'Camera permission is required to take photos';
          });
          return;
        }
      }

      // Try to take photo
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 800,
        maxHeight: 600,
        imageQuality: 85,
      );

      if (photo != null) {
        setState(() {
          _selectedImage = photo;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to take photo: $e';
      });
    }
  }

  // Submit form to create or update entity
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check if logged in
    if (!_isLoggedIn) {
      setState(() {
        _errorMessage = 'You must be logged in to create or edit entities';
      });
      return;
    }

    try {
      setState(() {
        _isSubmitting = true;
        _errorMessage = null;
      });

      final title = _titleController.text;
      final lat = double.parse(_latController.text);
      final lon = double.parse(_lonController.text);

      if (_isEditMode && _editEntityId != null) {
        // Update existing entity
        File? imageFile;

        if (_selectedImage != null && !kIsWeb) {
          imageFile = File(_selectedImage!.path);
        }

        final success = await _apiService.updateEntity(
          _editEntityId!,
          title,
          lat,
          lon,
          imageFile,
        );

        if (success) {
          // Update entity in provider
          final updatedEntity = Entity(
            id: _editEntityId,
            title: title,
            lat: lat,
            lon: lon,
            image: widget.entityToEdit?.image, // Keep old image if no new one
            properties: _locationInfo,
          );

          Provider.of<EntityProvider>(context, listen: false)
              .updateEntity(updatedEntity);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isOfflineMode
                  ? 'Entity saved locally and will be synced when online'
                  : 'Entity updated successfully'),
              backgroundColor: _isOfflineMode ? Colors.orange : Colors.green,
            ),
          );

          Navigator.pop(context);
        }
      } else {
        // Create new entity
        if (_selectedImage == null) {
          setState(() {
            _errorMessage = 'Please select an image';
            _isSubmitting = false;
          });
          return;
        }

        int newEntityId;

        if (kIsWeb) {
          // For web, use a different approach
          // Since File isn't available in web, use a custom method
          newEntityId = await _createEntityWeb(title, lat, lon);
        } else {
          // Use version with image for mobile
          final File imageFile = File(_selectedImage!.path);

          // Process the image before uploading
          final processedImage = await ImageUtils.resizeAndCompressImage(imageFile);

          newEntityId = await _apiService.createEntity(
            title,
            lat,
            lon,
            processedImage,
          );
        }

        // Add new entity to provider
        final newEntity = Entity(
          id: newEntityId,
          title: title,
          lat: lat,
          lon: lon,
          image: 'pending_image.jpg', // This will be updated when we fetch again
          properties: _locationInfo,
        );

        Provider.of<EntityProvider>(context, listen: false).addEntity(newEntity);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isOfflineMode
                ? 'Entity saved locally and will be synced when online'
                : 'Entity created successfully'),
            backgroundColor: _isOfflineMode ? Colors.orange : Colors.green,
          ),
        );

        // Reset form
        _titleController.clear();

        setState(() {
          _selectedImage = null;
          _webImageBytes = null;
          _locationInfo = null;
        });

        _getCurrentLocation();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  // Create entity for web
  Future<int> _createEntityWeb(String title, double lat, double lon) async {
    // For web, we can't use the File class, so we need a different approach
    // We'll use a MultipartRequest with bytes instead of File
    try {
      // This is a simplified version for testing
      // In a real app, you would need to handle the image bytes properly
      return await _apiService.createEntityWithoutImage(title, lat, lon);
    } catch (e) {
      print('Error creating entity on web: $e');
      throw e;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isEditMode ? 'Edit Entity' : 'Create New Entity',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Login required warning
                  if (!_isLoggedIn)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.warning, color: Colors.orange),
                              SizedBox(width: 8),
                              Text(
                                'Login Required',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'You must be logged in to create or edit entities. Your changes will not be saved.',
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pushReplacementNamed(context, '/login');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                            ),
                            child: const Text('Login Now'),
                          ),
                        ],
                      ),
                    ),

                  // Offline mode warning
                  if (_isOfflineMode)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.cloud_off, color: Colors.blue),
                              SizedBox(width: 8),
                              Text(
                                'Offline Mode',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'You are currently offline. Your changes will be saved locally and synchronized when you are back online.',
                          ),
                        ],
                      ),
                    ),

                  // Title field
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Title',
                      border: const OutlineInputBorder(),
                      suffixIcon: _isLoadingLocationInfo
                          ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2)
                      )
                          : null,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a title';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Latitude field
                  TextFormField(
                    controller: _latController,
                    decoration: const InputDecoration(
                      labelText: 'Latitude',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter latitude';
                      }

                      try {
                        final lat = double.parse(value);

                        if (lat < -90 || lat > 90) {
                          return 'Latitude must be between -90 and 90';
                        }
                      } catch (e) {
                        return 'Please enter a valid number';
                      }

                      return null;
                    },
                    onChanged: (value) {
                      if (!_isOfflineMode && value.isNotEmpty && _lonController.text.isNotEmpty) {
                        try {
                          double lat = double.parse(value);
                          double lon = double.parse(_lonController.text);

                          _getLocationInfo(lat, lon);
                        } catch (e) {
                          // Ignore parsing errors here as they're handled in the validator
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Longitude field
                  TextFormField(
                    controller: _lonController,
                    decoration: const InputDecoration(
                      labelText: 'Longitude',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter longitude';
                      }

                      try {
                        final lon = double.parse(value);

                        if (lon < -180 || lon > 180) {
                          return 'Longitude must be between -180 and 180';
                        }
                      } catch (e) {
                        return 'Please enter a valid number';
                      }

                      return null;
                    },
                    onChanged: (value) {
                      if (!_isOfflineMode && value.isNotEmpty && _latController.text.isNotEmpty) {
                        try {
                          double lat = double.parse(_latController.text);
                          double lon = double.parse(value);

                          _getLocationInfo(lat, lon);
                        } catch (e) {
                          // Ignore parsing errors here as they're handled in the validator
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Use current location button
                  ElevatedButton.icon(
                    onPressed: _getCurrentLocation,
                    icon: const Icon(Icons.my_location),
                    label: const Text('Use Current Location'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),

                  // Display location info if available
                  if (_locationInfo != null && _locationInfo!['features'] != null && _locationInfo!['features'].isNotEmpty)
                    _buildLocationInfo(_locationInfo!),

                  const SizedBox(height: 20),

                  // Image selection
                  const Text(
                    'Entity Image:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (_selectedImage != null)
                    _buildSelectedImagePreview()
                  else if (_isEditMode && widget.entityToEdit?.image != null)
                    Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          ApiService.getImageUrl(widget.entityToEdit!.image),
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(child: CircularProgressIndicator());
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(Icons.error, size: 50, color: Colors.red),
                            );
                          },
                        ),
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text('No image selected'),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Image selection buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _takePhoto,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Take Photo'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.photo_library),
                          label: const Text('From Gallery'),
                        ),
                      ),
                    ],
                  ),

                  if (kIsWeb)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Note: Camera is not directly supported in web apps. "Take Photo" will open the gallery instead.',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontStyle: FontStyle.italic,
                          fontSize: 12,
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Error message
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade800),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Submit button
                  ElevatedButton(
                    onPressed: _isSubmitting || !_isLoggedIn ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: _isSubmitting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(_isEditMode ? 'Update Entity' : 'Create Entity'),
                  ),
                ],
              ),
            ),
          ),

          // Offline mode indicator
          if (_isOfflineMode)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.cloud_off, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Offline Mode',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Build selected image preview based on platform
  Widget _buildSelectedImagePreview() {
    if (kIsWeb && _webImageBytes != null) {
      // For web, use Image.memory with the bytes
      return Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            _webImageBytes!,
            fit: BoxFit.cover,
          ),
        ),
      );
    } else if (!kIsWeb && _selectedImage != null) {
      // For mobile, use Image.file
      return Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(_selectedImage!.path),
            fit: BoxFit.cover,
          ),
        ),
      );
    } else {
      // Fallback if something went wrong
      return Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text('Error loading image preview'),
        ),
      );
    }
  }

  // Build location info widget
  Widget _buildLocationInfo(Map<String, dynamic> locationInfo) {
    if (locationInfo['features'] == null || locationInfo['features'].isEmpty) {
      return const SizedBox.shrink();
    }

    final feature = locationInfo['features'][0];

    if (feature['properties'] == null) {
      return const SizedBox.shrink();
    }

    final properties = feature['properties'];

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Location Information:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          if (properties['formatted'] != null)
            Text('Address: ${properties['formatted']}'),
          if (properties['country'] != null)
            Text('Country: ${properties['country']}'),
          if (properties['state'] != null)
            Text('State: ${properties['state']}'),
          if (properties['city'] != null)
            Text('City: ${properties['city']}'),
          if (properties['district'] != null)
            Text('District: ${properties['district']}'),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }
}
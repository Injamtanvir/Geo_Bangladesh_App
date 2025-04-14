import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'map_screen.dart';
import 'entity_form.dart';
import 'entity_list.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  bool _isOfflineMode = false;
  bool _isLoggedIn = false;
  String _username = '';
  bool _hasPendingChanges = false;

  final ApiService _apiService = ApiService();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();

    _screens = [
      const MapScreen(),
      const EntityFormScreen(),
      const EntityListScreen(),
    ];

    _checkConnectivity();
    _checkAuthStatus();
    _checkPendingChanges();
  }

  // Check if user is logged in
  Future<void> _checkAuthStatus() async {
    await _apiService.initialize();
    final username = await _apiService.getCurrentUsername();

    setState(() {
      _isLoggedIn = _apiService.isLoggedIn();
      _username = username ?? 'Guest';
    });
  }

  // Check for pending offline changes
  Future<void> _checkPendingChanges() async {
    final hasPending = await _apiService.hasPendingChanges();
    setState(() {
      _hasPendingChanges = hasPending;
    });
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

      // Show snackbar when connectivity changes
      if (result == ConnectivityResult.none) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You are offline. Using cached data.'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You are back online. Syncing changes...'),
            backgroundColor: Colors.green,
          ),
        );

        // Try to sync offline changes
        if (_isLoggedIn) {
          _syncOfflineChanges();
        }
      }
    });
  }

  // Sync offline changes when back online
  Future<void> _syncOfflineChanges() async {
    if (_isLoggedIn && !_isOfflineMode && _hasPendingChanges) {
      try {
        final success = await _apiService.syncOfflineChanges();
        if (success) {
          setState(() {
            _hasPendingChanges = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All changes synced successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        print('Error syncing changes: $e');
      }
    }
  }

  // Force sync offline changes
  Future<void> _forceSyncOfflineChanges() async {
    if (!_isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to sync changes'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_isOfflineMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot sync while offline'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final success = await _apiService.syncOfflineChanges();

      // Close loading indicator
      Navigator.pop(context);

      if (success) {
        setState(() {
          _hasPendingChanges = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All changes synced successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to sync some changes. Try again later.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      // Close loading indicator
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error syncing changes: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Force download all images for offline use
  Future<void> _forceDownloadAllImages() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      await _apiService.downloadAllImages();

      // Close loading indicator
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All images downloaded for offline use'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Close loading indicator
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error downloading images: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Logout the user
  Future<void> _logout() async {
    // Check if there are pending changes
    if (_hasPendingChanges) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unsaved Changes'),
          content: const Text(
              'You have unsaved changes that haven\'t been synced yet. '
                  'If you log out now, these changes might be lost. Do you still want to log out?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Log Out'),
            ),
          ],
        ),
      );

      if (confirm != true) {
        return;
      }
    }

    await _apiService.logout();
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bangladesh Geo Entities'),
        actions: [
          // Sync button
          if (_hasPendingChanges && !_isOfflineMode)
            IconButton(
              icon: const Icon(Icons.sync),
              tooltip: 'Sync Changes',
              onPressed: _forceSyncOfflineChanges,
            ),

          // Offline mode indicator
          if (_isOfflineMode)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Tooltip(
                message: 'Offline Mode',
                child: Icon(
                  Icons.cloud_off,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                color: Colors.green,
              ),
              accountName: Text(
                _isLoggedIn ? _username : 'Guest User',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              accountEmail: Text(
                _isLoggedIn ? 'Logged In' : 'Not Logged In',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(
                  _isLoggedIn ? Icons.person : Icons.person_outline,
                  color: Colors.green,
                  size: 36,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.map),
              title: const Text('Map'),
              selected: _selectedIndex == 0,
              onTap: () {
                _selectScreen(0);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_location),
              title: const Text('Form'),
              selected: _selectedIndex == 1,
              onTap: () {
                // If not logged in, prompt to login
                if (!_isLoggedIn) {
                  _showLoginRequiredDialog('add new entities');
                } else {
                  _selectScreen(1);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.list),
              title: const Text('List'),
              selected: _selectedIndex == 2,
              onTap: () {
                _selectScreen(2);
              },
            ),
            const Divider(),
            // Offline status
            ListTile(
              leading: Icon(
                _isOfflineMode ? Icons.cloud_off : Icons.cloud_done,
                color: _isOfflineMode ? Colors.orange : Colors.green,
              ),
              title: Text(
                _isOfflineMode ? 'Offline Mode' : 'Online Mode',
                style: TextStyle(
                  color: _isOfflineMode ? Colors.orange : Colors.green,
                ),
              ),
              subtitle: Text(
                _isOfflineMode
                    ? 'Using cached data'
                    : 'Connected to server',
                style: TextStyle(fontSize: 12),
              ),
            ),
            // Pending changes status
            if (_hasPendingChanges)
              ListTile(
                leading: const Icon(Icons.sync_problem, color: Colors.orange),
                title: const Text(
                  'Pending Changes',
                  style: TextStyle(color: Colors.orange),
                ),
                subtitle: const Text(
                  'Some changes need to be synced',
                  style: TextStyle(fontSize: 12),
                ),
                onTap: _isOfflineMode ? null : _forceSyncOfflineChanges,
              ),
            // Download images for offline
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Download All Images'),
              subtitle: const Text(
                'For offline viewing',
                style: TextStyle(fontSize: 12),
              ),
              onTap: _isOfflineMode ? null : _forceDownloadAllImages,
            ),
            const Divider(),
            // Authentication
            if (_isLoggedIn)
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: _logout,
              )
            else
              ListTile(
                leading: const Icon(Icons.login),
                title: const Text('Login'),
                onTap: () {
                  Navigator.pushReplacementNamed(context, '/login');
                },
              ),
          ],
        ),
      ),
      body: _screens[_selectedIndex],
    );
  }

  void _selectScreen(int index) {
    setState(() {
      _selectedIndex = index;
    });
    Navigator.pop(context); // Close the drawer
  }

  // Show dialog when login is required
  void _showLoginRequiredDialog(String action) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Login Required'),
        content: Text('You need to be logged in to $action.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close drawer
              Navigator.pushNamed(context, '/login');
            },
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }
}
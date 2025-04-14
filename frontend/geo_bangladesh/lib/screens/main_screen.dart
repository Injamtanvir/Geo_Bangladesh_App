import 'package:flutter/material.dart';
import 'map_screen.dart';
import 'entity_form.dart';
import 'entity_list.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final List<Widget> _screens = [
    const MapScreen(),
    const EntityFormScreen(),
    const EntityListScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bangladesh Geo Entities'),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.green,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Geographic Entities',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Manage locations in Bangladesh',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
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
                _selectScreen(1);
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
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/main_screen.dart';
import 'models/entity.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => EntityProvider(),
      child: MaterialApp(
        title: 'Bangladesh Geo Entities',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.green,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: const MainScreen(),
      ),
    );
  }
}

// Provider to manage entity data across the app
class EntityProvider extends ChangeNotifier {
  List<Entity> _entities = [];

  List<Entity> get entities => _entities;

  void setEntities(List<Entity> entities) {
    _entities = entities;
    notifyListeners();
  }

  void addEntity(Entity entity) {
    _entities.add(entity);
    notifyListeners();
  }

  void updateEntity(Entity updatedEntity) {
    final index = _entities.indexWhere((entity) => entity.id == updatedEntity.id);
    if (index >= 0) {
      _entities[index] = updatedEntity;
      notifyListeners();
    }
  }

  void deleteEntity(int id) {
    _entities.removeWhere((entity) => entity.id == id);
    notifyListeners();
  }
}
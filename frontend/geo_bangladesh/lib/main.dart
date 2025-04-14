import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'screens/main_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'models/entity.dart';
import 'services/api_service.dart';
import 'database/database_helper.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize database
  final dbHelper = DatabaseHelper();
  await dbHelper.database;

  // Initialize API service
  final apiService = ApiService();
  await apiService.initialize();

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
        initialRoute: '/login',
        routes: {
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/main': (context) => const MainScreen(),
        },
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
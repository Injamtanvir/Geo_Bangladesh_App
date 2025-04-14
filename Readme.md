# Bangladesh Geo Entities

A Flutter application for managing geographic entities in Bangladesh. This app allows users to create, view, edit, and delete geographic entities with locations on a map.

## Features

- **Map View**: Display all entities on a Google Map centered on Bangladesh
- **Entity Form**: Create and edit entities with current GPS location
- **Entity List**: View all entities in a list with details
- **User Authentication**: Secure API access with login/registration
- **Offline Mode**: Cache entities for offline viewing
- **Image Upload**: Take photos or select from gallery
- **Location Info**: Get address details using Geoapify

## Setup Instructions

### Prerequisites

- Flutter SDK (3.0.0 or higher)
- Android Studio or VS Code with Flutter extensions
- Android device/emulator or iOS device/simulator

### Flutter App Setup

1. Clone the repository:
   ```
   git clone https://github.com/your-username/geo_bangladesh.git
   cd geo_bangladesh
   ```

2. Get dependencies:
   ```
   flutter pub get
   ```

3. Update Google Maps API Key:
   - Open `android/app/src/main/AndroidManifest.xml`
   - Replace the API key with your own Google Maps API key

4. Update API Endpoint:
   - Open `lib/services/api_service.dart`
   - Update the `baseUrl` to your API endpoint (Django backend or the provided endpoint)

5. Run the app:
   ```
   flutter run
   ```

### Django Backend Setup (Optional)

If you want to run your own backend instead of using the provided API:

1. Navigate to Django project folder
   ```
   cd backend
   ```

2. Create a virtual environment:
   ```
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. Install dependencies:
   ```
   pip install django djangorestframework django-cors-headers pillow
   ```

4. Run migrations:
   ```
   python manage.py makemigrations
   python manage.py migrate
   ```

5. Create a superuser:
   ```
   python manage.py createsuperuser
   ```

6. Start the server:
   ```
   python manage.py runserver
   ```

7. Access the admin panel at http://localhost:8000/admin/

## API Documentation

### Endpoints

- `GET /api.php`: Get all entities
- `POST /api.php`: Create a new entity
- `PUT /api.php`: Update an existing entity
- `DELETE /api.php?id={id}`: Delete an entity

### Authentication Endpoints (Django Backend)

- `POST /api/login/`: Login with username and password
- `POST /api/register/`: Register a new user
- `POST /api/logout/`: Logout (requires authentication)

## Technologies Used

- **Flutter**: Cross-platform UI framework
- **Google Maps**: Map integration
- **SQLite**: Local database for offline caching
- **Django**: Backend API (optional)
- **Geoapify**: Geocoding and location info
- **Provider**: State management
- **HTTP**: API requests
- **Image Picker**: Camera and gallery integration

## Challenges and Solutions

- **Cross-platform Image Handling**: Implemented different strategies for web and mobile
- **Offline Support**: Created SQLite database to cache entities and images
- **Authentication**: Implemented token-based auth with secure storage

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgements

- BRAC University CSE 489: Mobile Application Development course
- Google Maps API
- Geoapify API
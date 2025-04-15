# Bangladesh Geo App

A Flutter application for managing geographic entities in Bangladesh. This app allows users to create, view, edit, and delete geographic points of interest on a map centered on Bangladesh.

## Features

- **Interactive Map**: View all entities on a Google Map centered on Bangladesh
- **Entity Management**: Create, edit, and delete geographic entities
- **Offline Support**: Store and access data locally when offline
- **Image Handling**: Upload and view images for each location
- **User Authentication**: Secure login and registration system

## Project Structure

The project is divided into two main parts:

### Backend (Django)
- REST API for data management
- MongoDB for data storage
- Authentication with token-based system
- Image storage and retrieval

### Frontend (Flutter)
- Cross-platform mobile application
- Google Maps integration
- Camera and gallery integration for images
- SQLite local database for offline caching

## Setup Instructions

### Backend Setup

1. Clone the repository
2. Navigate to the backend directory: `cd Geo_Bangladesh_App/backend`
3. Install the requirements: `pip install -r requirements.txt`
4. Set up environment variables in `.env` file
5. Run migrations: `python manage.py migrate`
6. Start the server: `python manage.py runserver`

### Frontend Setup

1. Navigate to the frontend directory: `cd Geo_Bangladesh_App/frontend/geo_bangladesh`
2. Install Flutter dependencies: `flutter pub get`
3. Update the API endpoints in `lib/services/api_service.dart` to match your backend URL
4. Run the app: `flutter run`

## API Endpoints

The app uses the following API endpoints:

- `GET /api.php`: Fetch all entities
- `POST /api.php`: Create a new entity
- `PUT /api.php`: Update an existing entity
- `DELETE /api.php`: Delete an entity

## Configuration

- The Google Maps API key should be added to `android/app/src/main/AndroidManifest.xml` and `web/index.html`
- Update the API base URL in `lib/services/api_service.dart` to point to your backend server

## Troubleshooting

- If you encounter issues with Google Maps on web, ensure you've properly set up your API key in `web/index.html`
- For authentication issues, check that your token is being properly stored and sent with requests
- If images fail to load, verify that the base URL for images is correctly configured

## Dependencies

- Flutter 3.0.0+
- Google Maps Flutter 2.5.0+
- HTTP 1.1.0+
- Image Picker 1.0.4+
- SQLite 2.3.0+
- Connectivity Plus 5.0.1+
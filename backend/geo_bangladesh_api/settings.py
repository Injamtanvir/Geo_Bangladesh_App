"""
Django settings for geo_bangladesh_api project.
"""
import os
from pathlib import Path
from decouple import config

# Build paths inside the project like this: BASE_DIR / 'subdir'.
BASE_DIR = Path(__file__).resolve().parent.parent

# SECURITY WARNING: keep the secret key used in production secret!
SECRET_KEY = config('SECRET_KEY', default='django-insecure-your-secret-key-here')

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = config('DEBUG', default=False, cast=bool)

ALLOWED_HOSTS = ['geo-bangladesh-app.onrender.com', 'localhost', '127.0.0.1', '*']

# Application definition
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'rest_framework',
    'rest_framework.authtoken',
    'corsheaders',
    'api',
    'whitenoise.runserver_nostatic',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'geo_bangladesh_api.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'geo_bangladesh_api.wsgi.application'

# MongoDB Configuration
MONGODB_URI = config('MONGODB_URI', default='mongodb://localhost:27017/geo_bangladesh')

# Ensure MongoDB URI is correctly formatted
if not (MONGODB_URI.startswith('mongodb://') or MONGODB_URI.startswith('mongodb+srv://')):
    print(f"WARNING: Invalid MongoDB URI format. Updating to correct format.")
    # MongoDB Atlas provided URIs sometimes include <password> in angle brackets
    if '<' in MONGODB_URI and '>' in MONGODB_URI:
        # Replace <password> with actual password without angle brackets
        MONGODB_URI = MONGODB_URI.replace('<GeoBangladeshApp123>', 'GeoBangladeshApp123')
    
    # Ensure URI starts with proper protocol
    if not (MONGODB_URI.startswith('mongodb://') or MONGODB_URI.startswith('mongodb+srv://')):
        MONGODB_URI = 'mongodb+srv://GeoBangladeshApp:GeoBangladeshApp123@geobangladeshapp.qty9xmu.mongodb.net/?retryWrites=true&w=majority&appName=GeoBangladeshApp'

# Parse the database name from the URI or use a default
DB_NAME = 'geo_bangladesh'  # Default database name

try:
    if 'mongodb+srv://' in MONGODB_URI:
        # For MongoDB Atlas URI
        parts = MONGODB_URI.split('/')
        if len(parts) > 3 and '?' in parts[3]:
            DB_NAME = parts[3].split('?')[0]
        elif len(parts) > 3 and parts[3]:
            DB_NAME = parts[3]
    elif 'mongodb://' in MONGODB_URI:
        # For standard MongoDB URI
        parts = MONGODB_URI.split('/')
        if len(parts) > 3 and parts[3]:
            DB_NAME = parts[3].split('?')[0] if '?' in parts[3] else parts[3]
    
    print(f"Using MongoDB database: {DB_NAME}")
except Exception as e:
    print(f"Error parsing database name: {e}. Using default: {DB_NAME}")

# We'll use Django's default database for models
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'db.sqlite3',
    }
}

# Initialize PyMongo client
try:
    import pymongo
    MONGO_CLIENT = pymongo.MongoClient(MONGODB_URI)
    # Test connection
    MONGO_CLIENT.server_info()
    print("Successfully connected to MongoDB")
    MONGO_DB = MONGO_CLIENT[DB_NAME]  # Use the database name explicitly
except Exception as e:
    print(f"ERROR connecting to MongoDB: {e}")
    # Fallback for development/testing
    import pymongo
    MONGO_CLIENT = pymongo.MongoClient('mongodb://localhost:27017/')
    MONGO_DB = MONGO_CLIENT['geo_bangladesh']
    print("Using fallback local MongoDB")

# Password validation
AUTH_PASSWORD_VALIDATORS = [
    {
        'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator',
    },
]

# Internationalization
LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True

# Static files (CSS, JavaScript, Images)
STATIC_URL = '/static/'
STATIC_ROOT = os.path.join(BASE_DIR, 'staticfiles')
STATICFILES_STORAGE = 'whitenoise.storage.CompressedManifestStaticFilesStorage'

# Media files
MEDIA_URL = '/images/'
MEDIA_ROOT = os.path.join(BASE_DIR, 'images')

# Default primary key field type
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# Rest Framework Settings
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'rest_framework.authentication.TokenAuthentication',
        'rest_framework.authentication.SessionAuthentication',
    ],
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.IsAuthenticatedOrReadOnly',
    ],
}

# CORS Settings
CORS_ALLOW_ALL_ORIGINS = True
CORS_ALLOW_CREDENTIALS = True
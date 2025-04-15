from rest_framework import serializers
from django.contrib.auth.models import User
from .models import GeoEntity, OfflineImage

class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ('id', 'username', 'email')

class GeoEntitySerializer(serializers.ModelSerializer):
    class Meta:
        model = GeoEntity
        fields = ('id', 'title', 'lat', 'lon', 'image', 'properties', 'created_at', 'updated_at')
        read_only_fields = ('id', 'created_at', 'updated_at')

class OfflineImageSerializer(serializers.ModelSerializer):
    class Meta:
        model = OfflineImage
        fields = ('id', 'entity', 'user', 'local_path', 'last_synced')
        read_only_fields = ('id', 'last_synced')
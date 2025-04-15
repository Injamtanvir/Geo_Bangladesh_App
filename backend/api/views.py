from rest_framework import viewsets, permissions, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework.authtoken.models import Token
from rest_framework.authtoken.views import ObtainAuthToken
from django.contrib.auth import authenticate
from django.contrib.auth.models import User
from django.conf import settings
from .models import GeoEntity, OfflineImage
from .serializers import GeoEntitySerializer, UserSerializer, OfflineImageSerializer
import os

class LoginView(ObtainAuthToken):
    def post(self, request, *args, **kwargs):
        username = request.data.get('username')
        password = request.data.get('password')
        user = authenticate(username=username, password=password)
        
        if user:
            token, created = Token.objects.get_or_create(user=user)
            return Response({
                'success': True,
                'token': token.key,
                'user_id': user.pk,
                'username': user.username
            })
        else:
            return Response({
                'success': False,
                'error': 'Invalid credentials'
            }, status=status.HTTP_400_BAD_REQUEST)

@api_view(['POST'])
@permission_classes([permissions.AllowAny])
def register_user(request):
    username = request.data.get('username')
    password = request.data.get('password')
    email = request.data.get('email', '')
    
    if not username or not password:
        return Response({
            'success': False,
            'error': 'Please provide both username and password'
        }, status=status.HTTP_400_BAD_REQUEST)
    
    # Check if user already exists
    if User.objects.filter(username=username).exists():
        return Response({
            'success': False,
            'error': 'Username already exists'
        }, status=status.HTTP_400_BAD_REQUEST)
    
    # Create user
    user = User.objects.create_user(username=username, password=password, email=email)
    token, created = Token.objects.get_or_create(user=user)
    
    return Response({
        'success': True,
        'token': token.key,
        'user_id': user.pk,
        'username': user.username
    })

@api_view(['POST'])
def logout(request):
    if request.user.is_authenticated:
        # Delete the token to logout
        Token.objects.filter(user=request.user).delete()
        return Response({
            'success': True,
            'message': 'Successfully logged out'
        })
    return Response({
        'success': False,
        'error': 'Not logged in'
    })

@api_view(['GET'])
@permission_classes([permissions.AllowAny])
def check_server(request):
    return Response({
        'status': 'online',
        'message': 'Server is running'
    })

class GeoEntityViewSet(viewsets.ModelViewSet):
    queryset = GeoEntity.objects.all()
    serializer_class = GeoEntitySerializer
    
    def get_queryset(self):
        # Return all entities regardless of owner
        return GeoEntity.objects.all()
    
    def perform_create(self, serializer):
        # Set the owner when creating an entity
        serializer.save(user=self.request.user)
    
    def update(self, request, *args, **kwargs):
        instance = self.get_object()
        # Check if the user is the owner of the entity
        if instance.user != request.user:
            return Response({
                'success': False,
                'error': 'You can only update your own entities'
            }, status=status.HTTP_403_FORBIDDEN)
        return super().update(request, *args, **kwargs)
    
    def destroy(self, request, *args, **kwargs):
        instance = self.get_object()
        # Check if the user is the owner of the entity
        if instance.user != request.user:
            return Response({
                'success': False,
                'error': 'You can only delete your own entities'
            }, status=status.HTTP_403_FORBIDDEN)
        
        # Delete the image file if it exists
        if instance.image and os.path.isfile(instance.image.path):
            os.remove(instance.image.path)
            
        return super().destroy(request, *args, **kwargs)
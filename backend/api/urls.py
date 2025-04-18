from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import GeoEntityViewSet, LoginView, register_user, logout, check_server

router = DefaultRouter()
router.register(r'entities', GeoEntityViewSet)

urlpatterns = [
    path('', include(router.urls)),
    path('login/', LoginView.as_view(), name='login'),
    path('register/', register_user, name='register'),
    path('logout/', logout, name='logout'),
    path('check/', check_server, name='check_server'),
]
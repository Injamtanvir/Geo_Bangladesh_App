from django.db import models
from django.contrib.auth.models import User

class GeoEntity(models.Model):
    """
    Geographic entity model
    """
    id = models.AutoField(primary_key=True)
    title = models.CharField(max_length=255)
    lat = models.FloatField()
    lon = models.FloatField()
    image = models.ImageField(upload_to='', null=True, blank=True)
    properties = models.JSONField(null=True, blank=True)
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='entities')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    def __str__(self):
        return self.title

class OfflineImage(models.Model):
    """
    Model to track which images have been downloaded for offline use
    """
    entity = models.ForeignKey(GeoEntity, on_delete=models.CASCADE, related_name='offline_images')
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    local_path = models.CharField(max_length=500)
    last_synced = models.DateTimeField(auto_now=True)
    
    class Meta:
        unique_together = ['entity', 'user']
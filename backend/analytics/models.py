from django.db import models

class AnalyticsSnapshot(models.Model):
    name = models.CharField(max_length=100) 
    snapshot_date = models.DateField(db_index=True)
    payload = models.JSONField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ("name", "snapshot_date")
        ordering = ["-snapshot_date"]

    def __str__(self):
        return f"{self.name} @ {self.snapshot_date}"

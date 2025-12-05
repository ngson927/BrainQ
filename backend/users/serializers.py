from rest_framework import serializers
from django.contrib.auth.password_validation import validate_password
from .models import CustomUser


# =========================
# User Serializer
# =========================
class UserSerializer(serializers.ModelSerializer):
    streak = serializers.SerializerMethodField(read_only=True)

    class Meta:
        model = CustomUser
        fields = [
            'id',
            'username',
            'email',
            'first_name',
            'last_name',
            'role',
            'timezone',        
            'is_suspended',
            'is_active',
            'date_joined',
            'streak',
        ]
        read_only_fields = ['is_suspended', 'is_active', 'date_joined', 'streak']

    def get_streak(self, obj):
        """Return streak summary for this user (from Achievements)."""
        if hasattr(obj, "achievements") and obj.achievements:
            return {
                "current_streak": obj.achievements.current_streak,
                "best_streak": obj.achievements.best_streak,
                "total_study_days": obj.achievements.total_study_days,
                "badges": obj.achievements.badges,
            }
        return None



# =========================
# Registration Serializer
# =========================
class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(
        write_only=True,
        required=True,
        validators=[validate_password],
        style={'input_type': 'password'}
    )
    password2 = serializers.CharField(
        write_only=True,
        required=True,
        style={'input_type': 'password'}
    )

    class Meta:
        model = CustomUser
        fields = [
            'username',
            'email',
            'first_name',
            'last_name',
            'password',
            'password2',
            'timezone',
        ]

    def validate(self, attrs):
        if attrs['password'] != attrs['password2']:
            raise serializers.ValidationError({"password": "Passwords do not match."})
        return attrs

    def create(self, validated_data):
        validated_data.pop('password2', None)

        timezone = validated_data.pop('timezone', 'UTC')

        user = CustomUser.objects.create_user(
            username=validated_data['username'],
            email=validated_data['email'],
            password=validated_data['password'],
            first_name=validated_data.get('first_name', ''),
            last_name=validated_data.get('last_name', ''),
            timezone=timezone,
        )
        return user
# =========================
# Update Profile Serializer
# =========================
class UpdateProfileSerializer(serializers.ModelSerializer):
    password = serializers.CharField(
        write_only=True, required=False, validators=[validate_password]
    )

    class Meta:
        model = CustomUser
        fields = [
            'username',
            'email',
            'first_name',
            'last_name',
            'timezone',
            'password',
        ]

    def validate_username(self, value):
        user = self.context['request'].user

        if CustomUser.objects.exclude(id=user.id).filter(username=value).exists():
            raise serializers.ValidationError("This username is already in use.")

        return value

    def validate_email(self, value):
        user = self.context['request'].user

        if CustomUser.objects.exclude(id=user.id).filter(email=value).exists():
            raise serializers.ValidationError("This email is already in use.")

        return value

    def update(self, instance, validated_data):
        password = validated_data.pop("password", None)

        # Update basic fields
        for attr, value in validated_data.items():
            setattr(instance, attr, value)

        # If password provided, hash it
        if password:
            instance.set_password(password)

        instance.save()
        return instance
# =========================
# Delete Account Serializer
# =========================
class DeleteAccountSerializer(serializers.Serializer):
    confirm = serializers.BooleanField()

    def validate_confirm(self, value):
        if value is not True:
            raise serializers.ValidationError("You must confirm account deletion.")
        return value

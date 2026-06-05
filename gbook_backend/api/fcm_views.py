# gbook_backend/api/views_fcm_addition.py
# ─────────────────────────────────────────────────────────────────────────────
# ADD THESE TWO VIEWS to the bottom of your existing gbook_backend/api/views.py
# ─────────────────────────────────────────────────────────────────────────────
# Copy everything below the dashed line and paste at the end of views.py
# ─────────────────────────────────────────────────────────────────────────────

from rest_framework import generics, status, permissions
from rest_framework.views import APIView
from rest_framework.response import Response


class FCMTokenRegisterView(APIView):
    """Register or update FCM push token for the current user."""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        token = request.data.get('token')
        device_type = request.data.get('device_type', 'android')

        if not token:
            return Response(
                {'error': 'token is required'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Import here so the app still works before firebase-admin is installed
        try:
            from .models import FCMToken
            FCMToken.objects.update_or_create(
                user=request.user,
                defaults={
                    'token': token,
                    'device_type': device_type,
                    'is_active': True,
                }
            )
            return Response(
                {'message': 'FCM token registered'},
                status=status.HTTP_200_OK
            )
        except ImportError:
            # FCMToken model not migrated yet — silently succeed
            return Response(
                {'message': 'FCM not configured on server yet'},
                status=status.HTTP_200_OK
            )
        except Exception as e:
            return Response(
                {'error': str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class FCMTokenUnregisterView(APIView):
    """Remove FCM token on logout."""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        try:
            from .models import FCMToken
            FCMToken.objects.filter(user=request.user).update(is_active=False)
        except Exception:
            pass
        return Response(
            {'message': 'FCM token unregistered'},
            status=status.HTTP_200_OK
        )
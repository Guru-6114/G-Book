"""
G-Book API Views
Complete REST API for G-Book application
"""
import random
import string
from datetime import timedelta, date
from django.utils import timezone
from django.db.models import Sum, Count, Q, F
from rest_framework import generics, status, permissions, viewsets
from rest_framework.decorators import api_view, permission_classes, action
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from .models import User, OTPVerification, Business, Customer, Transaction, PaymentReminder
from .serializers import (
    SendOTPSerializer, VerifyOTPSerializer, UserSerializer,
    UpdateProfileSerializer, BusinessSerializer, CreateBusinessSerializer,
    CustomerListSerializer, CustomerDetailSerializer, CreateCustomerSerializer,
    TransactionSerializer, CreateTransactionSerializer,
    DashboardSummarySerializer, PaymentReminderSerializer
)


def generate_otp(length=6):
    """Generate a random OTP"""
    return ''.join(random.choices(string.digits, k=length))


def get_tokens_for_user(user):
    """Generate JWT tokens for user"""
    refresh = RefreshToken.for_user(user)
    return {
        'refresh': str(refresh),
        'access': str(refresh.access_token),
    }


# ─── Auth Views ───────────────────────────────────────────────────────

class SendOTPView(APIView):
    """Send OTP to phone number"""
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = SendOTPSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        phone = serializer.validated_data['phone']

        # Invalidate existing OTPs
        OTPVerification.objects.filter(phone=phone, is_verified=False).update(
            is_verified=True
        )

        # Generate new OTP
        otp = generate_otp()
        expires_at = timezone.now() + timedelta(minutes=10)

        OTPVerification.objects.create(
            phone=phone,
            otp=otp,
            expires_at=expires_at
        )

        # In production, send via SMS gateway (Twilio, MSG91, etc.)
        # For development, return OTP in response
        response_data = {
            'message': 'OTP sent successfully',
            'phone': phone,
            'expires_in': 600,  # 10 minutes in seconds
        }

        # DEV ONLY: include OTP in response
        if True:  # Replace with: if settings.DEBUG
            response_data['otp'] = otp

        return Response(response_data, status=status.HTTP_200_OK)


class VerifyOTPView(APIView):
    """Verify OTP and login/register user"""
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = VerifyOTPSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        phone = serializer.validated_data['phone']
        otp = serializer.validated_data['otp']

        # Find latest unverified OTP
        try:
            otp_obj = OTPVerification.objects.filter(
                phone=phone,
                is_verified=False
            ).latest('created_at')
        except OTPVerification.DoesNotExist:
            return Response(
                {'error': 'No OTP found. Please request a new OTP.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Check expiry
        if otp_obj.is_expired():
            return Response(
                {'error': 'OTP has expired. Please request a new OTP.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Check attempts
        if otp_obj.attempts >= 3:
            return Response(
                {'error': 'Too many attempts. Please request a new OTP.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Verify OTP
        if otp_obj.otp != otp:
            otp_obj.attempts += 1
            otp_obj.save()
            remaining = 3 - otp_obj.attempts
            return Response(
                {'error': f'Invalid OTP. {remaining} attempts remaining.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Mark OTP as verified
        otp_obj.is_verified = True
        otp_obj.save()

        # Get or create user
        user, created = User.objects.get_or_create(
            phone=phone,
            defaults={'is_verified': True}
        )

        if not user.is_verified:
            user.is_verified = True
            user.save()

        # Generate tokens
        tokens = get_tokens_for_user(user)

        return Response({
            'message': 'Login successful',
            'is_new_user': created,
            'user': UserSerializer(user).data,
            'tokens': tokens,
        }, status=status.HTTP_200_OK)


class LogoutView(APIView):
    """Blacklist refresh token"""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        try:
            refresh_token = request.data.get('refresh')
            token = RefreshToken(refresh_token)
            token.blacklist()
            return Response({'message': 'Logged out successfully'}, status=status.HTTP_200_OK)
        except Exception:
            return Response({'error': 'Invalid token'}, status=status.HTTP_400_BAD_REQUEST)


# ─── User / Profile Views ──────────────────────────────────────────────

class ProfileView(generics.RetrieveUpdateAPIView):
    """Get and update user profile"""
    permission_classes = [permissions.IsAuthenticated]

    def get_serializer_class(self):
        if self.request.method in ['PUT', 'PATCH']:
            return UpdateProfileSerializer
        return UserSerializer

    def get_object(self):
        return self.request.user


# ─── Business Views ───────────────────────────────────────────────────

class BusinessView(generics.RetrieveUpdateAPIView):
    """Get and update business profile"""
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = BusinessSerializer

    def get_object(self):
        try:
            return self.request.user.business
        except Business.DoesNotExist:
            return None

    def get(self, request, *args, **kwargs):
        obj = self.get_object()
        if not obj:
            return Response({'detail': 'Business not found'}, status=status.HTTP_404_NOT_FOUND)
        return Response(BusinessSerializer(obj).data)

    def put(self, request, *args, **kwargs):
        return self.update(request, *args, **kwargs)

    def patch(self, request, *args, **kwargs):
        return self.partial_update(request, *args, **kwargs)

    def update(self, request, *args, **kwargs):
        obj = self.get_object()
        partial = kwargs.pop('partial', False)
        serializer = CreateBusinessSerializer(
            obj, data=request.data, partial=partial,
            context={'request': request}
        )
        serializer.is_valid(raise_exception=True)
        business = serializer.save()
        return Response(BusinessSerializer(business).data)


class CreateBusinessView(generics.CreateAPIView):
    """Create business profile"""
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = CreateBusinessSerializer


# ─── Dashboard View ────────────────────────────────────────────────────

class DashboardView(APIView):
    """Business dashboard summary"""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        customers = Customer.objects.filter(user=user, is_active=True)

        total_given = Transaction.objects.filter(
            user=user, transaction_type='credit', is_deleted=False
        ).aggregate(total=Sum('amount'))['total'] or 0

        total_received = Transaction.objects.filter(
            user=user, transaction_type='debit', is_deleted=False
        ).aggregate(total=Sum('amount'))['total'] or 0

        # Customers who owe (positive balance)
        customers_who_owe = sum(1 for c in customers if c.balance > 0)
        # Customers you owe (negative balance)
        customers_you_owe = sum(1 for c in customers if c.balance < 0)

        # Recent transactions
        recent_transactions = Transaction.objects.filter(
            user=user, is_deleted=False
        ).select_related('customer').order_by('-created_at')[:5]

        return Response({
            'total_customers': customers.count(),
            'total_given': total_given,
            'total_received': total_received,
            'net_balance': total_given - total_received,
            'customers_who_owe': customers_who_owe,
            'customers_you_owe': customers_you_owe,
            'recent_transactions': TransactionSerializer(recent_transactions, many=True).data,
        })


# ─── Customer Views ────────────────────────────────────────────────────

class CustomerListCreateView(generics.ListCreateAPIView):
    """List and create customers"""
    permission_classes = [permissions.IsAuthenticated]
    search_fields = ['name', 'phone', 'email']
    ordering_fields = ['name', 'created_at']
    ordering = ['name']

    def get_serializer_class(self):
        if self.request.method == 'POST':
            return CreateCustomerSerializer
        return CustomerListSerializer

    def get_queryset(self):
        user = self.request.user
        qs = Customer.objects.filter(user=user, is_active=True)

        # Filter by balance type
        balance_filter = self.request.query_params.get('balance_filter')
        if balance_filter == 'to_receive':
            # Customers who owe us
            qs = [c for c in qs if c.balance > 0]
        elif balance_filter == 'to_pay':
            # We owe these customers
            qs = [c for c in qs if c.balance < 0]

        return qs

    def list(self, request, *args, **kwargs):
        queryset = self.filter_queryset(self.get_queryset())
        if isinstance(queryset, list):
            serializer = CustomerListSerializer(queryset, many=True)
            return Response(serializer.data)
        page = self.paginate_queryset(queryset)
        if page is not None:
            serializer = CustomerListSerializer(page, many=True)
            return self.get_paginated_response(serializer.data)
        serializer = CustomerListSerializer(queryset, many=True)
        return Response(serializer.data)


class CustomerDetailView(generics.RetrieveUpdateDestroyAPIView):
    """Get, update, delete customer"""
    permission_classes = [permissions.IsAuthenticated]

    def get_serializer_class(self):
        if self.request.method in ['PUT', 'PATCH']:
            return CreateCustomerSerializer
        return CustomerDetailSerializer

    def get_queryset(self):
        return Customer.objects.filter(user=self.request.user)

    def destroy(self, request, *args, **kwargs):
        customer = self.get_object()
        customer.is_active = False
        customer.save()
        return Response({'message': 'Customer archived successfully'}, status=status.HTTP_200_OK)


class CustomerTransactionsView(generics.ListAPIView):
    """Get all transactions for a customer"""
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = TransactionSerializer

    def get_queryset(self):
        customer_id = self.kwargs.get('pk')
        return Transaction.objects.filter(
            user=self.request.user,
            customer_id=customer_id,
            is_deleted=False
        ).select_related('customer').order_by('-transaction_date', '-created_at')


# ─── Transaction Views ─────────────────────────────────────────────────

class TransactionListCreateView(generics.ListCreateAPIView):
    """List all transactions and create new"""
    permission_classes = [permissions.IsAuthenticated]
    search_fields = ['description', 'reference_number', 'customer__name']
    filterset_fields = ['transaction_type', 'payment_mode']
    ordering = ['-transaction_date', '-created_at']

    def get_serializer_class(self):
        if self.request.method == 'POST':
            return CreateTransactionSerializer
        return TransactionSerializer

    def get_queryset(self):
        user = self.request.user
        qs = Transaction.objects.filter(
            user=user, is_deleted=False
        ).select_related('customer')

        # Date range filter
        start_date = self.request.query_params.get('start_date')
        end_date = self.request.query_params.get('end_date')
        if start_date:
            qs = qs.filter(transaction_date__gte=start_date)
        if end_date:
            qs = qs.filter(transaction_date__lte=end_date)

        return qs

    def create(self, request, *args, **kwargs):
        serializer = CreateTransactionSerializer(
            data=request.data, context={'request': request}
        )
        serializer.is_valid(raise_exception=True)
        transaction = serializer.save()
        return Response(
            TransactionSerializer(transaction).data,
            status=status.HTTP_201_CREATED
        )


class TransactionDetailView(generics.RetrieveDestroyAPIView):
    """Get and delete a transaction"""
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = TransactionSerializer

    def get_queryset(self):
        return Transaction.objects.filter(user=self.request.user, is_deleted=False)

    def destroy(self, request, *args, **kwargs):
        transaction = self.get_object()
        transaction.soft_delete()
        return Response({'message': 'Transaction deleted successfully'}, status=status.HTTP_200_OK)


# ─── Reports View ──────────────────────────────────────────────────────

class ReportsView(APIView):
    """Generate reports"""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        report_type = request.query_params.get('type', 'monthly')

        if report_type == 'monthly':
            # Last 6 months data
            months_data = []
            for i in range(5, -1, -1):
                d = timezone.now() - timedelta(days=30 * i)
                month_start = d.replace(day=1)
                if d.month == 12:
                    month_end = d.replace(day=31)
                else:
                    month_end = d.replace(month=d.month + 1, day=1) - timedelta(days=1)

                given = Transaction.objects.filter(
                    user=user, transaction_type='credit', is_deleted=False,
                    transaction_date__gte=month_start.date(),
                    transaction_date__lte=month_end.date()
                ).aggregate(t=Sum('amount'))['t'] or 0

                received = Transaction.objects.filter(
                    user=user, transaction_type='debit', is_deleted=False,
                    transaction_date__gte=month_start.date(),
                    transaction_date__lte=month_end.date()
                ).aggregate(t=Sum('amount'))['t'] or 0

                months_data.append({
                    'month': d.strftime('%b %Y'),
                    'given': float(given),
                    'received': float(received),
                    'net': float(received - given),
                })

            return Response({'monthly_data': months_data})

        return Response({'error': 'Invalid report type'}, status=status.HTTP_400_BAD_REQUEST)


# ─── Reminder Views ────────────────────────────────────────────────────

class ReminderListCreateView(generics.ListCreateAPIView):
    """List and create payment reminders"""
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = PaymentReminderSerializer

    def get_queryset(self):
        return PaymentReminder.objects.filter(
            user=self.request.user
        ).select_related('customer')


class SendReminderView(APIView):
    """Send SMS reminder to customer"""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        try:
            customer = Customer.objects.get(id=pk, user=request.user)
        except Customer.DoesNotExist:
            return Response({'error': 'Customer not found'}, status=status.HTTP_404_NOT_FOUND)

        balance = customer.balance
        if balance <= 0:
            return Response({'error': 'No outstanding balance'}, status=status.HTTP_400_BAD_REQUEST)

        message = request.data.get('message', f'Dear {customer.name}, you have an outstanding balance of ₹{balance}. Please settle at your earliest convenience. - G-Book')

        # In production: Send via SMS gateway
        # For now, just return success
        return Response({
            'message': f'Reminder sent to {customer.name} ({customer.phone})',
            'sms_content': message,
        })
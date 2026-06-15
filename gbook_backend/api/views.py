import random
import logging
from django.utils import timezone
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.exceptions import TokenError

from .models import User, OTPRecord, BusinessProfile, Customer, Transaction, FCMToken
from .serializers import (
    UserSerializer, BusinessProfileSerializer,
    CustomerSerializer, TransactionSerializer
)

logger = logging.getLogger('api')


def generate_otp():
    return str(random.randint(100000, 999999))


# ── POST /api/auth/send-otp/ ──────────────────────────────────────────────────
@api_view(['POST'])
@permission_classes([AllowAny])
def send_otp(request):
    phone = request.data.get('phone', '').strip()

    if not phone or len(phone) != 10 or not phone.isdigit():
        return Response(
            {'error': 'Valid 10-digit phone number is required'},
            status=status.HTTP_400_BAD_REQUEST
        )

    OTPRecord.objects.filter(phone=phone).delete()
    otp = generate_otp()
    OTPRecord.objects.create(phone=phone, otp=otp)

    print(f"\n{'='*45}")
    print(f"  📱 OTP for {phone}  →  {otp}")
    print(f"{'='*45}\n")
    logger.info(f"OTP generated for {phone}: {otp}")

    return Response({'message': 'OTP sent successfully'}, status=status.HTTP_200_OK)


# ── POST /api/auth/verify-otp/ ───────────────────────────────────────────────
@api_view(['POST'])
@permission_classes([AllowAny])
def verify_otp(request):
    phone = request.data.get('phone', '').strip()
    otp = request.data.get('otp', '').strip()

    if not phone or not otp:
        return Response(
            {'error': 'Phone and OTP are required'},
            status=status.HTTP_400_BAD_REQUEST
        )

    try:
        record = OTPRecord.objects.filter(
            phone=phone, otp=otp, is_verified=False
        ).latest('created_at')
    except OTPRecord.DoesNotExist:
        return Response({'error': 'Invalid OTP'}, status=status.HTTP_400_BAD_REQUEST)

    if record.is_expired():
        return Response({'error': 'OTP has expired'}, status=status.HTTP_400_BAD_REQUEST)

    record.is_verified = True
    record.save()

    user, is_new = User.objects.get_or_create(
        phone=phone,
        defaults={'username': phone}
    )

    refresh = RefreshToken.for_user(user)

    return Response({
        'message': 'OTP verified successfully',
        'access': str(refresh.access_token),
        'refresh': str(refresh),
        'is_new_user': is_new,
        'user': UserSerializer(user).data,
    }, status=status.HTTP_200_OK)


# ── POST /api/auth/logout/ ────────────────────────────────────────────────────
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def logout(request):
    try:
        refresh_token = request.data.get('refresh')
        if refresh_token:
            token = RefreshToken(refresh_token)
            token.blacklist()
    except (TokenError, Exception):
        pass
    return Response({'message': 'Logged out successfully'}, status=status.HTTP_200_OK)


# ── POST /api/auth/fcm-token/ ← NEW ──────────────────────────────────────────
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def save_fcm_token(request):
    token = request.data.get('token', '').strip()
    if not token:
        # Empty token = logout, delete it
        FCMToken.objects.filter(user=request.user).delete()
        return Response({'status': 'token removed'})

    FCMToken.objects.update_or_create(
        user=request.user,
        defaults={'token': token}
    )
    logger.info(f"FCM token saved for {request.user.phone}")
    return Response({'status': 'saved'})


# ── GET/PATCH /api/profile/ ───────────────────────────────────────────────────
@api_view(['GET', 'PATCH'])
@permission_classes([IsAuthenticated])
def profile(request):
    try:
        bp = BusinessProfile.objects.get(user=request.user)
    except BusinessProfile.DoesNotExist:
        if request.method == 'GET':
            return Response({'detail': 'Profile not found'}, status=status.HTTP_404_NOT_FOUND)
        bp = None

    if request.method == 'GET':
        return Response(BusinessProfileSerializer(bp).data)

    data = request.data
    if bp is None:
        bp = BusinessProfile(user=request.user, phone=request.user.phone)

    if 'businessName' in data:
        bp.business_name = data['businessName']
    if 'ownerName' in data:
        bp.owner_name = data['ownerName']
    if 'phone' in data:
        bp.phone = data['phone']
    if 'email' in data:
        bp.email = data['email']
    if 'address' in data:
        bp.address = data['address']
    if 'gstin' in data:
        bp.gstin = data['gstin']
    if 'category' in data:
        bp.category = data['category']
    bp.save()

    return Response(BusinessProfileSerializer(bp).data)


# ── POST /api/business/ ───────────────────────────────────────────────────────
@api_view(['GET', 'POST', 'PATCH'])
@permission_classes([IsAuthenticated])
def business(request):
    if request.method == 'GET':
        try:
            bp = BusinessProfile.objects.get(user=request.user)
            return Response(BusinessProfileSerializer(bp).data)
        except BusinessProfile.DoesNotExist:
            return Response({'detail': 'Not found'}, status=status.HTTP_404_NOT_FOUND)

    data = request.data
    bp, _ = BusinessProfile.objects.get_or_create(
        user=request.user,
        defaults={'phone': request.user.phone, 'business_name': '', 'owner_name': ''}
    )
    bp.business_name = data.get('businessName', bp.business_name)
    bp.owner_name = data.get('ownerName', bp.owner_name)
    bp.phone = data.get('phone', bp.phone)
    bp.email = data.get('email', bp.email)
    bp.address = data.get('address', bp.address)
    bp.gstin = data.get('gstin', bp.gstin)
    bp.category = data.get('category', bp.category)
    bp.save()
    return Response(BusinessProfileSerializer(bp).data)


# ── /api/customers/ ───────────────────────────────────────────────────────────
@api_view(['GET', 'POST'])
@permission_classes([IsAuthenticated])
def customers(request):
    if request.method == 'GET':
        qs = Customer.objects.filter(user=request.user)
        balance_filter = request.query_params.get('balance_filter')
        if balance_filter == 'receivable':
            qs = qs.filter(balance__gt=0)
        elif balance_filter == 'payable':
            qs = qs.filter(balance__lt=0)
        return Response(CustomerSerializer(qs, many=True).data)

    serializer = CustomerSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    customer = Customer.objects.create(
        user=request.user,
        name=request.data['name'],
        phone=request.data.get('phone'),
        email=request.data.get('email'),
        address=request.data.get('address'),
    )
    return Response(CustomerSerializer(customer).data, status=status.HTTP_201_CREATED)


@api_view(['GET', 'PATCH', 'DELETE'])
@permission_classes([IsAuthenticated])
def customer_detail(request, pk):
    try:
        customer = Customer.objects.get(pk=pk, user=request.user)
    except Customer.DoesNotExist:
        return Response({'error': 'Not found'}, status=status.HTTP_404_NOT_FOUND)

    if request.method == 'GET':
        return Response(CustomerSerializer(customer).data)
    if request.method == 'PATCH':
        for field in ['name', 'phone', 'email', 'address']:
            if field in request.data:
                setattr(customer, field, request.data[field])
        customer.save()
        return Response(CustomerSerializer(customer).data)
    if request.method == 'DELETE':
        customer.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


# ── /api/transactions/ ────────────────────────────────────────────────────────
@api_view(['GET', 'POST'])
@permission_classes([IsAuthenticated])
def transactions(request):
    if request.method == 'GET':
        qs = Transaction.objects.filter(user=request.user)
        if request.query_params.get('customer'):
            qs = qs.filter(customer_id=request.query_params['customer'])
        if request.query_params.get('start_date'):
            qs = qs.filter(date__gte=request.query_params['start_date'])
        if request.query_params.get('end_date'):
            qs = qs.filter(date__lte=request.query_params['end_date'])
        if request.query_params.get('transaction_type'):
            qs = qs.filter(transaction_type=request.query_params['transaction_type'])
        return Response(TransactionSerializer(qs, many=True).data)

    data = request.data
    tx = Transaction.objects.create(
        user=request.user,
        amount=data['amount'],
        is_income=data.get('isIncome', True),
        transaction_type=data.get('type', 'credit'),
        payment_mode=data.get('paymentMode', 'cash'),
        category=data.get('category'),
        note=data.get('note'),
        description=data.get('description'),
        reference_number=data.get('referenceNumber'),
        customer_id=data.get('customerId'),
    )
    return Response(TransactionSerializer(tx).data, status=status.HTTP_201_CREATED)


@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def transaction_detail(request, pk):
    try:
        tx = Transaction.objects.get(pk=pk, user=request.user)
        tx.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)
    except Transaction.DoesNotExist:
        return Response({'error': 'Not found'}, status=status.HTTP_404_NOT_FOUND)


# ── /api/dashboard/ ───────────────────────────────────────────────────────────
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def dashboard(request):
    from django.db.models import Sum
    qs = Transaction.objects.filter(user=request.user)
    total_in = qs.filter(is_income=True).aggregate(s=Sum('amount'))['s'] or 0
    total_out = qs.filter(is_income=False).aggregate(s=Sum('amount'))['s'] or 0
    customers_count = Customer.objects.filter(user=request.user).count()
    return Response({
        'totalIn': float(total_in),
        'totalOut': float(total_out),
        'balance': float(total_in - total_out),
        'customersCount': customers_count,
    })
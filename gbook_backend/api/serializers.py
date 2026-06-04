"""
G-Book API Serializers
"""
from rest_framework import serializers
from django.utils import timezone
from datetime import timedelta
from .models import User, OTPVerification, Business, Customer, Transaction, PaymentReminder


# ─── Auth Serializers ───────────────────────────────────────────────

class SendOTPSerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=15)

    def validate_phone(self, value):
        # Strip spaces and validate format
        value = value.strip().replace(' ', '')
        if not value.startswith('+'):
            value = '+91' + value if len(value) == 10 else value
        return value


class VerifyOTPSerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=15)
    otp = serializers.CharField(max_length=6, min_length=4)

    def validate_phone(self, value):
        value = value.strip().replace(' ', '')
        if not value.startswith('+'):
            value = '+91' + value if len(value) == 10 else value
        return value


class UserSerializer(serializers.ModelSerializer):
    has_business = serializers.SerializerMethodField()
    business_name = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = ['id', 'phone', 'name', 'email', 'profile_image',
                  'is_verified', 'date_joined', 'has_business', 'business_name']
        read_only_fields = ['id', 'phone', 'is_verified', 'date_joined']

    def get_has_business(self, obj):
        return hasattr(obj, 'business')

    def get_business_name(self, obj):
        if hasattr(obj, 'business'):
            return obj.business.business_name
        return None


class UpdateProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['name', 'email', 'profile_image']


# ─── Business Serializers ────────────────────────────────────────────

class BusinessSerializer(serializers.ModelSerializer):
    class Meta:
        model = Business
        fields = '__all__'
        read_only_fields = ['id', 'user', 'created_at', 'updated_at']


class CreateBusinessSerializer(serializers.ModelSerializer):
    class Meta:
        model = Business
        fields = ['business_name', 'business_type', 'address', 'city',
                  'state', 'pincode', 'gst_number', 'logo', 'currency']

    def create(self, validated_data):
        user = self.context['request'].user
        # Update or create business
        business, _ = Business.objects.update_or_create(
            user=user,
            defaults=validated_data
        )
        return business


# ─── Customer Serializers ────────────────────────────────────────────

class CustomerListSerializer(serializers.ModelSerializer):
    balance = serializers.DecimalField(max_digits=12, decimal_places=2, read_only=True)
    last_transaction_date = serializers.SerializerMethodField()
    transaction_count = serializers.SerializerMethodField()

    class Meta:
        model = Customer
        fields = ['id', 'name', 'phone', 'email', 'profile_image',
                  'balance', 'last_transaction_date', 'transaction_count',
                  'is_active', 'created_at']

    def get_last_transaction_date(self, obj):
        last = obj.transactions.filter(is_deleted=False).first()
        if last:
            return last.transaction_date
        return None

    def get_transaction_count(self, obj):
        return obj.transactions.filter(is_deleted=False).count()


class CustomerDetailSerializer(serializers.ModelSerializer):
    balance = serializers.DecimalField(max_digits=12, decimal_places=2, read_only=True)
    total_given = serializers.SerializerMethodField()
    total_received = serializers.SerializerMethodField()

    class Meta:
        model = Customer
        fields = ['id', 'name', 'phone', 'email', 'address', 'profile_image',
                  'notes', 'is_active', 'balance', 'total_given', 'total_received',
                  'created_at', 'updated_at']
        read_only_fields = ['id', 'created_at', 'updated_at']

    def get_total_given(self, obj):
        from django.db.models import Sum
        total = obj.transactions.filter(
            transaction_type='credit', is_deleted=False
        ).aggregate(t=Sum('amount'))['t']
        return total or 0

    def get_total_received(self, obj):
        from django.db.models import Sum
        total = obj.transactions.filter(
            transaction_type='debit', is_deleted=False
        ).aggregate(t=Sum('amount'))['t']
        return total or 0


class CreateCustomerSerializer(serializers.ModelSerializer):
    class Meta:
        model = Customer
        fields = ['name', 'phone', 'email', 'address', 'profile_image', 'notes']

    def validate_phone(self, value):
        user = self.context['request'].user
        # Check uniqueness per user (excluding self on update)
        qs = Customer.objects.filter(user=user, phone=value)
        if self.instance:
            qs = qs.exclude(id=self.instance.id)
        if value and qs.exists():
            raise serializers.ValidationError("A customer with this phone number already exists.")
        return value

    def create(self, validated_data):
        validated_data['user'] = self.context['request'].user
        return super().create(validated_data)


# ─── Transaction Serializers ──────────────────────────────────────────

class TransactionSerializer(serializers.ModelSerializer):
    customer_name = serializers.CharField(source='customer.name', read_only=True)
    customer_phone = serializers.CharField(source='customer.phone', read_only=True)
    balance_after = serializers.SerializerMethodField()

    class Meta:
        model = Transaction
        fields = ['id', 'customer', 'customer_name', 'customer_phone',
                  'amount', 'transaction_type', 'payment_mode', 'description',
                  'reference_number', 'image', 'transaction_date',
                  'balance_after', 'created_at']
        read_only_fields = ['id', 'user', 'created_at']

    def get_balance_after(self, obj):
        return obj.customer.balance


class CreateTransactionSerializer(serializers.ModelSerializer):
    class Meta:
        model = Transaction
        fields = ['customer', 'amount', 'transaction_type', 'payment_mode',
                  'description', 'reference_number', 'image', 'transaction_date']

    def validate_amount(self, value):
        if value <= 0:
            raise serializers.ValidationError("Amount must be greater than 0.")
        return value

    def validate_customer(self, value):
        user = self.context['request'].user
        if value.user != user:
            raise serializers.ValidationError("Customer not found.")
        return value

    def create(self, validated_data):
        validated_data['user'] = self.context['request'].user
        return super().create(validated_data)


# ─── Dashboard / Summary Serializers ─────────────────────────────────

class DashboardSummarySerializer(serializers.Serializer):
    total_customers = serializers.IntegerField()
    total_given = serializers.DecimalField(max_digits=14, decimal_places=2)
    total_received = serializers.DecimalField(max_digits=14, decimal_places=2)
    net_balance = serializers.DecimalField(max_digits=14, decimal_places=2)
    customers_who_owe = serializers.IntegerField()
    customers_you_owe = serializers.IntegerField()


# ─── Reminder Serializers ─────────────────────────────────────────────

class PaymentReminderSerializer(serializers.ModelSerializer):
    customer_name = serializers.CharField(source='customer.name', read_only=True)
    customer_phone = serializers.CharField(source='customer.phone', read_only=True)

    class Meta:
        model = PaymentReminder
        fields = ['id', 'customer', 'customer_name', 'customer_phone',
                  'message', 'reminder_date', 'is_sent', 'sent_at', 'created_at']
        read_only_fields = ['id', 'user', 'is_sent', 'sent_at', 'created_at']

    def create(self, validated_data):
        validated_data['user'] = self.context['request'].user
        return super().create(validated_data)
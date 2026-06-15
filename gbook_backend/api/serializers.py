from rest_framework import serializers
from .models import User, BusinessProfile, Customer, Transaction


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['id', 'phone', 'username', 'email', 'date_joined']


class BusinessProfileSerializer(serializers.ModelSerializer):
    id = serializers.SerializerMethodField()
    businessName = serializers.CharField(source='business_name')
    ownerName = serializers.CharField(source='owner_name')
    createdAt = serializers.DateTimeField(source='created_at', read_only=True)

    class Meta:
        model = BusinessProfile
        fields = ['id', 'businessName', 'ownerName', 'phone', 'email',
                  'address', 'gstin', 'category', 'createdAt']

    def get_id(self, obj):
        return str(obj.id)


class CustomerSerializer(serializers.ModelSerializer):
    id = serializers.SerializerMethodField()
    createdAt = serializers.DateTimeField(source='created_at', read_only=True)

    class Meta:
        model = Customer
        fields = ['id', 'name', 'phone', 'email', 'address', 'balance', 'createdAt']

    def get_id(self, obj):
        return str(obj.id)


class TransactionSerializer(serializers.ModelSerializer):
    id = serializers.SerializerMethodField()
    isIncome = serializers.BooleanField(source='is_income')
    paymentMode = serializers.CharField(source='payment_mode')
    customerId = serializers.SerializerMethodField()
    referenceNumber = serializers.CharField(source='reference_number', allow_null=True, required=False)

    class Meta:
        model = Transaction
        fields = ['id', 'amount', 'isIncome', 'category', 'note', 'description',
                  'paymentMode', 'customerId', 'referenceNumber', 'date', 'type']

    def get_id(self, obj):
        return str(obj.id)

    def get_customerId(self, obj):
        return str(obj.customer.id) if obj.customer else None

    def to_representation(self, instance):
        data = super().to_representation(instance)
        data['type'] = instance.transaction_type
        data['date'] = instance.date.isoformat()
        return data
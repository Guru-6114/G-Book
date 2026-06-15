import random
from django.db import models
from django.contrib.auth.models import AbstractBaseUser, BaseUserManager, PermissionsMixin
from django.utils import timezone


# ── User Manager ──────────────────────────────────────────────────────────────
class UserManager(BaseUserManager):
    def create_user(self, phone, password=None, **extra_fields):
        if not phone:
            raise ValueError('Phone number is required')
        user = self.model(phone=phone, username=phone, **extra_fields)
        user.set_unusable_password()
        user.save(using=self._db)
        return user

    def create_superuser(self, phone, password=None, **extra_fields):
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        user = self.model(phone=phone, username=phone, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user


# ── Custom User ───────────────────────────────────────────────────────────────
class User(AbstractBaseUser, PermissionsMixin):
    phone = models.CharField(max_length=15, unique=True)
    username = models.CharField(max_length=50, unique=True, default='')
    email = models.EmailField(blank=True, null=True)
    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)
    date_joined = models.DateTimeField(default=timezone.now)

    objects = UserManager()

    USERNAME_FIELD = 'phone'
    REQUIRED_FIELDS = []

    class Meta:
        db_table = 'users'

    def __str__(self):
        return self.phone


# ── OTP Record ────────────────────────────────────────────────────────────────
class OTPRecord(models.Model):
    phone = models.CharField(max_length=15)
    otp = models.CharField(max_length=6)
    created_at = models.DateTimeField(auto_now_add=True)
    is_verified = models.BooleanField(default=False)

    class Meta:
        db_table = 'otp_records'
        ordering = ['-created_at']

    def is_expired(self):
        expiry_minutes = 10
        return (timezone.now() - self.created_at).total_seconds() > (expiry_minutes * 60)

    def __str__(self):
        return f"{self.phone} - {self.otp}"


# ── Business Profile ──────────────────────────────────────────────────────────
class BusinessProfile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='business_profile')
    business_name = models.CharField(max_length=200)
    owner_name = models.CharField(max_length=200)
    phone = models.CharField(max_length=15)
    email = models.EmailField(blank=True, null=True)
    address = models.TextField(blank=True, null=True)
    gstin = models.CharField(max_length=20, blank=True, null=True)
    category = models.CharField(max_length=100, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'business_profiles'

    def __str__(self):
        return self.business_name


# ── Customer ──────────────────────────────────────────────────────────────────
class Customer(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='customers')
    name = models.CharField(max_length=200)
    phone = models.CharField(max_length=15, blank=True, null=True)
    email = models.EmailField(blank=True, null=True)
    address = models.TextField(blank=True, null=True)
    balance = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'customers'
        ordering = ['name']

    def __str__(self):
        return self.name


# ── Transaction ───────────────────────────────────────────────────────────────
PAYMENT_MODE_CHOICES = [
    ('cash', 'Cash'), ('upi', 'UPI'), ('bank_transfer', 'Bank Transfer'),
    ('cheque', 'Cheque'), ('other', 'Other'),
]

TRANSACTION_TYPE_CHOICES = [
    ('credit', 'Credit'), ('debit', 'Debit'),
    ('income', 'Income'), ('expense', 'Expense'),
]


class Transaction(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='transactions')
    customer = models.ForeignKey(Customer, on_delete=models.SET_NULL, null=True, blank=True)
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    is_income = models.BooleanField(default=True)
    transaction_type = models.CharField(max_length=20, choices=TRANSACTION_TYPE_CHOICES, default='credit')
    payment_mode = models.CharField(max_length=20, choices=PAYMENT_MODE_CHOICES, default='cash')
    category = models.CharField(max_length=100, blank=True, null=True)
    note = models.TextField(blank=True, null=True)
    description = models.TextField(blank=True, null=True)
    reference_number = models.CharField(max_length=100, blank=True, null=True)
    date = models.DateTimeField(default=timezone.now)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'transactions'
        ordering = ['-date']

    def __str__(self):
        return f"{self.transaction_type} - {self.amount}"


# ── FCM Token ← NEW ───────────────────────────────────────────────────────────
class FCMToken(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='fcm_token')
    token = models.TextField()
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'fcm_tokens'

    def __str__(self):
        return f"{self.user.phone} - {self.token[:30]}..."
from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import User, OTPRecord, BusinessProfile, Customer, Transaction


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    list_display = ['phone', 'username', 'email', 'is_active', 'date_joined']
    search_fields = ['phone', 'email']
    ordering = ['-date_joined']
    fieldsets = (
        (None, {'fields': ('phone', 'username', 'password')}),
        ('Info', {'fields': ('email',)}),
        ('Permissions', {'fields': ('is_active', 'is_staff', 'is_superuser', 'groups', 'user_permissions')}),
    )
    add_fieldsets = (
        (None, {'fields': ('phone', 'username', 'password1', 'password2')}),
    )


@admin.register(OTPRecord)
class OTPAdmin(admin.ModelAdmin):
    list_display = ['phone', 'otp', 'created_at', 'is_verified']
    list_filter = ['is_verified']
    ordering = ['-created_at']


@admin.register(BusinessProfile)
class BusinessProfileAdmin(admin.ModelAdmin):
    list_display = ['business_name', 'owner_name', 'phone', 'category']


@admin.register(Customer)
class CustomerAdmin(admin.ModelAdmin):
    list_display = ['name', 'phone', 'balance', 'created_at']
    search_fields = ['name', 'phone']


@admin.register(Transaction)
class TransactionAdmin(admin.ModelAdmin):
    list_display = ['user', 'amount', 'is_income', 'transaction_type', 'payment_mode', 'date']
    list_filter = ['is_income', 'transaction_type', 'payment_mode']
"""
G-Book Admin Configuration
"""
from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import User, OTPVerification, Business, Customer, Transaction, PaymentReminder


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    list_display = ['phone', 'name', 'email', 'is_verified', 'is_active', 'date_joined']
    list_filter = ['is_verified', 'is_active', 'is_staff']
    search_fields = ['phone', 'name', 'email']
    ordering = ['-date_joined']
    # ✅ FIX: date_joined and last_login must be readonly (not editable form fields)
    readonly_fields = ['id', 'date_joined', 'last_login']
    fieldsets = (
        (None, {'fields': ('phone', 'password')}),
        ('Personal Info', {'fields': ('name', 'email', 'profile_image')}),
        ('Permissions', {'fields': (
            'is_active', 'is_staff', 'is_superuser',
            'is_verified', 'groups', 'user_permissions'
        )}),
        ('Dates', {'fields': ('date_joined', 'last_login')}),
    )
    add_fieldsets = (
        (None, {
            'classes': ('wide',),
            'fields': ('phone', 'name', 'password1', 'password2'),
        }),
    )


@admin.register(OTPVerification)
class OTPVerificationAdmin(admin.ModelAdmin):
    list_display = ['phone', 'otp', 'is_verified', 'attempts', 'created_at', 'expires_at']
    list_filter = ['is_verified']
    search_fields = ['phone']
    readonly_fields = ['id', 'created_at']


@admin.register(Business)
class BusinessAdmin(admin.ModelAdmin):
    list_display = ['business_name', 'user', 'city', 'state', 'created_at']
    search_fields = ['business_name', 'user__phone', 'user__name']
    readonly_fields = ['id', 'created_at', 'updated_at']


@admin.register(Customer)
class CustomerAdmin(admin.ModelAdmin):
    list_display = ['name', 'phone', 'user', 'is_active', 'created_at']
    list_filter = ['is_active']
    search_fields = ['name', 'phone', 'user__name']
    readonly_fields = ['id', 'created_at', 'updated_at']


@admin.register(Transaction)
class TransactionAdmin(admin.ModelAdmin):
    list_display = ['customer', 'amount', 'transaction_type', 'payment_mode',
                    'transaction_date', 'is_deleted']
    list_filter = ['transaction_type', 'payment_mode', 'is_deleted']
    search_fields = ['customer__name', 'description', 'reference_number']
    readonly_fields = ['id', 'created_at', 'updated_at']
    date_hierarchy = 'transaction_date'


@admin.register(PaymentReminder)
class PaymentReminderAdmin(admin.ModelAdmin):
    list_display = ['customer', 'reminder_date', 'is_sent', 'sent_at']
    list_filter = ['is_sent']
    search_fields = ['customer__name']
    readonly_fields = ['id', 'created_at']
"""
G-Book API URL Patterns
"""
from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from . import views

urlpatterns = [
    # ─── Auth ────────────────────────────────────
    path('auth/send-otp/', views.SendOTPView.as_view(), name='send-otp'),
    path('auth/verify-otp/', views.VerifyOTPView.as_view(), name='verify-otp'),
    path('auth/logout/', views.LogoutView.as_view(), name='logout'),
    path('auth/token/refresh/', TokenRefreshView.as_view(), name='token-refresh'),

    # ─── User Profile ─────────────────────────────
    path('profile/', views.ProfileView.as_view(), name='profile'),

    # ─── Business ─────────────────────────────────
    path('business/', views.BusinessView.as_view(), name='business'),
    path('business/create/', views.CreateBusinessView.as_view(), name='business-create'),

    # ─── Dashboard ────────────────────────────────
    path('dashboard/', views.DashboardView.as_view(), name='dashboard'),

    # ─── Customers ────────────────────────────────
    path('customers/', views.CustomerListCreateView.as_view(), name='customer-list'),
    path('customers/<uuid:pk>/', views.CustomerDetailView.as_view(), name='customer-detail'),
    path('customers/<uuid:pk>/transactions/', views.CustomerTransactionsView.as_view(), name='customer-transactions'),
    path('customers/<uuid:pk>/remind/', views.SendReminderView.as_view(), name='send-reminder'),

    # ─── Transactions ─────────────────────────────
    path('transactions/', views.TransactionListCreateView.as_view(), name='transaction-list'),
    path('transactions/<uuid:pk>/', views.TransactionDetailView.as_view(), name='transaction-detail'),

    # ─── Reports ──────────────────────────────────
    path('reports/', views.ReportsView.as_view(), name='reports'),

    # ─── Reminders ────────────────────────────────
    path('reminders/', views.ReminderListCreateView.as_view(), name='reminders'),
]
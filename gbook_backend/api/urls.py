from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from . import views

urlpatterns = [
    # Auth
    path('auth/send-otp/',      views.send_otp,          name='send-otp'),
    path('auth/verify-otp/',    views.verify_otp,        name='verify-otp'),
    path('auth/logout/',        views.logout,            name='logout'),
    path('auth/token/refresh/', TokenRefreshView.as_view(), name='token-refresh'),

    # Profile & Business
    path('profile/',            views.profile,           name='profile'),
    path('business/',           views.business,          name='business'),
    path('business/create/',    views.business,          name='business-create'),

    # Customers
    path('customers/',          views.customers,         name='customers'),
    path('customers/<int:pk>/', views.customer_detail,   name='customer-detail'),

    # Transactions
    path('transactions/',           views.transactions,       name='transactions'),
    path('transactions/<int:pk>/',  views.transaction_detail, name='transaction-detail'),

    # Dashboard
    path('dashboard/',          views.dashboard,         name='dashboard'),
    path('auth/fcm-token/', views.save_fcm_token, name='save-fcm-token'),
]
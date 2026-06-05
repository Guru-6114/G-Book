"""
gbook_backend/api/notifications.py
────────────────────────────────────────────────────────────────────────────
Firebase Cloud Messaging helper for sending push notifications from Django.
Uses firebase-admin SDK (install: pip install firebase-admin)
────────────────────────────────────────────────────────────────────────────
"""
import logging
import os
from pathlib import Path

logger = logging.getLogger(__name__)

# ── Lazy Firebase init (only once) ───────────────────────────────────────────

_firebase_initialized = False


def _init_firebase():
    global _firebase_initialized
    if _firebase_initialized:
        return True
    try:
        import firebase_admin
        from firebase_admin import credentials

        # Path to your downloaded service account JSON
        SERVICE_ACCOUNT_PATH = Path(__file__).resolve().parent.parent / \
            'firebase-service-account.json'

        if not SERVICE_ACCOUNT_PATH.exists():
            logger.error(
                f"Firebase service account not found at {SERVICE_ACCOUNT_PATH}. "
                "Download it from Firebase Console → Project Settings → Service Accounts."
            )
            return False

        if not firebase_admin._apps:
            cred = credentials.Certificate(str(SERVICE_ACCOUNT_PATH))
            firebase_admin.initialize_app(cred)

        _firebase_initialized = True
        logger.info("Firebase Admin initialized successfully")
        return True

    except ImportError:
        logger.error("firebase-admin not installed. Run: pip install firebase-admin")
        return False
    except Exception as e:
        logger.error(f"Firebase init error: {e}")
        return False


# ── Core send function ────────────────────────────────────────────────────────

def send_push_notification(
    token: str,
    title: str,
    body: str,
    data: dict = None,
    notification_type: str = 'general',
) -> bool:
    """
    Send a push notification to a single FCM token.

    Args:
        token: FCM device token
        title: Notification title
        body: Notification body text
        data: Extra data dict (all values must be strings)
        notification_type: 'general' | 'payment_reminder' | 'transaction'

    Returns:
        True on success, False on failure
    """
    if not _init_firebase():
        return False

    try:
        from firebase_admin import messaging

        # Ensure all data values are strings (FCM requirement)
        str_data = {str(k): str(v) for k, v in (data or {}).items()}
        str_data['type'] = notification_type

        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=str_data,
            token=token,
            android=messaging.AndroidConfig(
                priority='high',
                notification=messaging.AndroidNotification(
                    icon='ic_launcher',
                    color='#1A6B3C',           # GBook green
                    channel_id='general',
                    sound='default',
                    click_action='FLUTTER_NOTIFICATION_CLICK',
                ),
            ),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(
                        alert=messaging.ApsAlert(title=title, body=body),
                        badge=1,
                        sound='default',
                    ),
                ),
            ),
        )

        response = messaging.send(message)
        logger.info(f"FCM message sent: {response}")
        return True

    except Exception as e:
        logger.error(f"FCM send error for token {token[:20]}...: {e}")
        return False


def send_push_to_multiple(
    tokens: list,
    title: str,
    body: str,
    data: dict = None,
    notification_type: str = 'general',
) -> dict:
    """
    Send to multiple tokens using FCM MulticastMessage (max 500 tokens).

    Returns:
        {'success': int, 'failure': int, 'failed_tokens': list}
    """
    if not tokens:
        return {'success': 0, 'failure': 0, 'failed_tokens': []}

    if not _init_firebase():
        return {'success': 0, 'failure': len(tokens), 'failed_tokens': tokens}

    try:
        from firebase_admin import messaging

        str_data = {str(k): str(v) for k, v in (data or {}).items()}
        str_data['type'] = notification_type

        # FCM allows max 500 tokens per multicast
        results = {'success': 0, 'failure': 0, 'failed_tokens': []}

        for i in range(0, len(tokens), 500):
            batch = tokens[i:i + 500]
            multicast = messaging.MulticastMessage(
                notification=messaging.Notification(title=title, body=body),
                data=str_data,
                tokens=batch,
                android=messaging.AndroidConfig(
                    priority='high',
                    notification=messaging.AndroidNotification(
                        channel_id='general',
                        color='#1A6B3C',
                        click_action='FLUTTER_NOTIFICATION_CLICK',
                    ),
                ),
            )
            response = messaging.send_each_for_multicast(multicast)
            results['success'] += response.success_count
            results['failure'] += response.failure_count

            for j, resp in enumerate(response.responses):
                if not resp.success:
                    results['failed_tokens'].append(batch[j])

        logger.info(
            f"Multicast FCM: {results['success']} success, "
            f"{results['failure']} failure"
        )
        return results

    except Exception as e:
        logger.error(f"Multicast FCM error: {e}")
        return {'success': 0, 'failure': len(tokens), 'failed_tokens': tokens}


# ── Convenience helpers ───────────────────────────────────────────────────────

def notify_payment_reminder(token: str, customer_name: str, amount: float) -> bool:
    """Send a payment reminder notification to the business owner."""
    return send_push_notification(
        token=token,
        title=f"💰 Reminder Sent: {customer_name}",
        body=f"Payment reminder sent to {customer_name} for ₹{amount:.2f}",
        data={
            'customer_name': customer_name,
            'amount': str(amount),
        },
        notification_type='payment_reminder',
    )


def notify_new_transaction(
    token: str,
    customer_name: str,
    amount: float,
    transaction_type: str,  # 'credit' | 'debit'
) -> bool:
    """Notify business owner of a new transaction."""
    verb = 'gave' if transaction_type == 'credit' else 'received'
    emoji = '⬆️' if transaction_type == 'credit' else '⬇️'
    return send_push_notification(
        token=token,
        title=f"{emoji} Transaction: {customer_name}",
        body=f"You {verb} ₹{amount:.2f} {'to' if transaction_type == 'credit' else 'from'} {customer_name}",
        data={
            'customer_name': customer_name,
            'amount': str(amount),
            'transaction_type': transaction_type,
        },
        notification_type='transaction',
    )


def notify_low_stock(token: str, item_name: str, stock: float, unit: str) -> bool:
    """Notify business owner of low stock."""
    return send_push_notification(
        token=token,
        title=f"⚠️ Low Stock: {item_name}",
        body=f"Only {stock} {unit} remaining for {item_name}",
        data={'item_name': item_name, 'stock': str(stock)},
        notification_type='general',
    )
import firebase_admin
from firebase_admin import credentials, messaging

# Initialize Firebase
cred = credentials.Certificate("serviceAccountKey.json")
firebase_admin.initialize_app(cred)

# Your FCM Token
TOKEN = "daeO-PizQWSZqqBgdg2PfY:APA91bGTBaiHoAaxpr4Y2woMD-qlKkESqtpAZBaC3pFgYpjwaQYG4aAUA45A8G6j4X2ANpnDI-wXzOTDE9YEpaUd1D8AYNHavvC1Xb6Ki3n-jUUclSdnZzM"

# Build message
message = messaging.Message(
    notification=messaging.Notification(
        title="🎉 GBook Notification!",
        body="Push notifications are working perfectly!",
    ),
    android=messaging.AndroidConfig(
        priority="high",
        notification=messaging.AndroidNotification(
            sound="default",
            channel_id="high_importance_channel",
        ),
    ),
    token=TOKEN,
)

# Send it
response = messaging.send(message)
print(f"✅ Notification sent! Message ID: {response}")
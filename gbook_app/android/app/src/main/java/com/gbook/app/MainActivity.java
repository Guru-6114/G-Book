package com.gbook.app;

import android.Manifest;
import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.net.Uri;
import android.os.Build;
import android.provider.ContactsContract;
import android.telephony.SubscriptionInfo;
import android.telephony.SubscriptionManager;

import androidx.annotation.NonNull;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {

    private static final String CONTACTS_CHANNEL = "gbook/contacts";
    private static final String SIM_INFO_CHANNEL = "com.gbook.app/sim_info";
    private static final int PICK_CONTACT_REQUEST = 1001;
    private static final int CONTACTS_PERMISSION_REQUEST = 1002;

    private MethodChannel.Result pendingResult;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                CONTACTS_CHANNEL
        ).setMethodCallHandler((call, result) -> {
            if ("pickContact".equals(call.method)) {
                pendingResult = result;
                pickContact();
            } else {
                result.notImplemented();
            }
        });

        new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                SIM_INFO_CHANNEL
        ).setMethodCallHandler((call, result) -> {
            if ("getSimCards".equals(call.method)) {
                result.success(getSimCards());
            } else {
                result.notImplemented();
            }
        });
    }

    // ── SIM info ─────────────────────────────────────────────────────────────
    // Replaces the abandoned sim_data pub package (only supports Flutter's
    // old v1 embedding and no longer compiles). Uses SubscriptionManager
    // directly, same native-bridge pattern as the contacts picker below.
    private List<Map<String, Object>> getSimCards() {
        List<Map<String, Object>> cards = new ArrayList<>();

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP_MR1) {
            return cards; // SubscriptionManager requires API 22+
        }

        boolean granted = ContextCompat.checkSelfPermission(
                this, Manifest.permission.READ_PHONE_STATE)
                == PackageManager.PERMISSION_GRANTED;
        if (!granted) {
            return cards;
        }

        try {
            SubscriptionManager sm = SubscriptionManager.from(this);
            List<SubscriptionInfo> infos = sm.getActiveSubscriptionInfoList();
            if (infos == null) return cards;

            for (SubscriptionInfo info : infos) {
                Map<String, Object> card = new HashMap<>();
                card.put("slotIndex", info.getSimSlotIndex());
                CharSequence carrier = info.getCarrierName();
                CharSequence display = info.getDisplayName();
                card.put("carrierName", carrier != null ? carrier.toString() : null);
                card.put("displayName", display != null ? display.toString()
                        : "SIM " + (info.getSimSlotIndex() + 1));
                cards.add(card);
            }
        } catch (SecurityException e) {
            // permission revoked between check and call — return what we have
        }

        return cards;
    }

    // ── Contact picker ──────────────────────────────────────────────────────
    private void pickContact() {
        // Check READ_CONTACTS permission
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CONTACTS)
                != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(
                    this,
                    new String[]{Manifest.permission.READ_CONTACTS},
                    CONTACTS_PERMISSION_REQUEST
            );
        } else {
            openContactPicker();
        }
    }

    private void openContactPicker() {
        Intent intent = new Intent(Intent.ACTION_PICK, ContactsContract.Contacts.CONTENT_URI);
        startActivityForResult(intent, PICK_CONTACT_REQUEST);
    }

    @Override
    public void onRequestPermissionsResult(int requestCode,
                                           @NonNull String[] permissions,
                                           @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == CONTACTS_PERMISSION_REQUEST) {
            if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                openContactPicker();
            } else {
                if (pendingResult != null) {
                    pendingResult.error("PERMISSION_DENIED", "Contacts permission denied", null);
                    pendingResult = null;
                }
            }
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);

        if (requestCode != PICK_CONTACT_REQUEST) return;

        if (resultCode != Activity.RESULT_OK || data == null) {
            if (pendingResult != null) {
                pendingResult.success(null);
                pendingResult = null;
            }
            return;
        }

        Uri contactUri = data.getData();
        if (contactUri == null) {
            if (pendingResult != null) {
                pendingResult.success(null);
                pendingResult = null;
            }
            return;
        }

        Map<String, String> contactMap = new HashMap<>();

        // Get contact ID and display name
        Cursor cursor = getContentResolver().query(
                contactUri,
                new String[]{
                        ContactsContract.Contacts._ID,
                        ContactsContract.Contacts.DISPLAY_NAME
                },
                null, null, null
        );

        if (cursor != null && cursor.moveToFirst()) {
            int idIdx = cursor.getColumnIndex(ContactsContract.Contacts._ID);
            int nameIdx = cursor.getColumnIndex(ContactsContract.Contacts.DISPLAY_NAME);
            String contactId = idIdx >= 0 ? cursor.getString(idIdx) : null;
            String name = nameIdx >= 0 ? cursor.getString(nameIdx) : "";
            contactMap.put("name", name != null ? name : "");
            cursor.close();

            if (contactId != null) {
                // Get phone number
                Cursor phoneCursor = getContentResolver().query(
                        ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                        new String[]{ContactsContract.CommonDataKinds.Phone.NUMBER},
                        ContactsContract.CommonDataKinds.Phone.CONTACT_ID + " = ?",
                        new String[]{contactId},
                        null
                );
                if (phoneCursor != null && phoneCursor.moveToFirst()) {
                    int phoneIdx = phoneCursor.getColumnIndex(
                            ContactsContract.CommonDataKinds.Phone.NUMBER);
                    String phone = phoneIdx >= 0 ? phoneCursor.getString(phoneIdx) : "";
                    contactMap.put("phone", phone != null ? phone : "");
                    phoneCursor.close();
                } else {
                    contactMap.put("phone", "");
                }

                // Get email
                Cursor emailCursor = getContentResolver().query(
                        ContactsContract.CommonDataKinds.Email.CONTENT_URI,
                        new String[]{ContactsContract.CommonDataKinds.Email.ADDRESS},
                        ContactsContract.CommonDataKinds.Email.CONTACT_ID + " = ?",
                        new String[]{contactId},
                        null
                );
                if (emailCursor != null && emailCursor.moveToFirst()) {
                    int emailIdx = emailCursor.getColumnIndex(
                            ContactsContract.CommonDataKinds.Email.ADDRESS);
                    String email = emailIdx >= 0 ? emailCursor.getString(emailIdx) : "";
                    contactMap.put("email", email != null ? email : "");
                    emailCursor.close();
                } else {
                    contactMap.put("email", "");
                }

                // Get address
                Cursor addrCursor = getContentResolver().query(
                        ContactsContract.CommonDataKinds.StructuredPostal.CONTENT_URI,
                        new String[]{ContactsContract.CommonDataKinds.StructuredPostal.FORMATTED_ADDRESS},
                        ContactsContract.CommonDataKinds.StructuredPostal.CONTACT_ID + " = ?",
                        new String[]{contactId},
                        null
                );
                if (addrCursor != null && addrCursor.moveToFirst()) {
                    int addrIdx = addrCursor.getColumnIndex(
                            ContactsContract.CommonDataKinds.StructuredPostal.FORMATTED_ADDRESS);
                    String address = addrIdx >= 0 ? addrCursor.getString(addrIdx) : "";
                    contactMap.put("address", address != null ? address : "");
                    addrCursor.close();
                } else {
                    contactMap.put("address", "");
                }
            }
        } else {
            if (cursor != null) cursor.close();
        }

        if (pendingResult != null) {
            pendingResult.success(contactMap);
            pendingResult = null;
        }
    }
}
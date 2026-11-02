package app.grounded.password;

import android.app.*;
import android.content.*;
import android.content.pm.*;
import android.os.Bundle;
import android.view.*;
import android.widget.*;
import java.io.*;
import java.util.*;

/** Dependency-free instrumentation runner. Run only on a fresh test installation. */
public final class SecurityChecks extends Instrumentation {
    private int checks;
    private boolean restoreOnly;
    @Override public void onCreate(Bundle arguments) {
        super.onCreate(arguments);
        restoreOnly = arguments != null && "restore".equals(arguments.getString("mode"));
        start();
    }
    private void check(boolean value, String description) {
        if (!value) throw new AssertionError(description);
        checks++;
        Bundle progress = new Bundle(); progress.putString("stream", "PASS " + checks + ": " + description + "\n"); sendStatus(2, progress);
    }
    @Override public void onStart() {
        Bundle status = new Bundle(); status.putString("class", getClass().getName());
        status.putString("test", "securityAndUserFlow"); status.putInt("numtests", 1); status.putInt("current", 1);
        sendStatus(1, status);
        Bundle result = new Bundle();
        try {
            if (restoreOnly) checkFreshInstallationRestore(); else runChecks();
            status.putString("stream", "\n" + checks + " device checks passed.\n"); sendStatus(0, status);
            result.putString("stream", "\nOK (1 test, " + checks + " checks)\n"); finish(Activity.RESULT_OK, result);
        } catch (Throwable e) {
            status.putString("stack", e.toString()); status.putString("stream", "\nFAIL: " + e + "\n"); sendStatus(-2, status);
            result.putString("stream", "\nFAILURES!!!\n" + e + "\n"); finish(Activity.RESULT_CANCELED, result);
        }
    }
    private void checkFreshInstallationRestore() throws Exception {
        Context target = getTargetContext();
        check(!new VaultStore(target).exists(), "Restore starts without a local vault");
        java.security.KeyStore keys = java.security.KeyStore.getInstance("AndroidKeyStore"); keys.load(null);
        check(!keys.containsAlias("grounded.vault.device.v1"), "Restore starts without the original device key");
        Intent launch = target.getPackageManager().getLaunchIntentForPackage(target.getPackageName());
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK);
        Activity activity = startActivitySync(launch); waitForIdleSync();
        android.net.Uri document = android.net.Uri.parse("content://app.grounded.password.test.documents/backup.gpv");
        runOnMainSync(() -> ((MainActivity) activity).onActivityResult(11, Activity.RESULT_OK, new Intent().setData(document)));
        awaitText(activity, "Restore and replace vault");
        setField(activity, "Backup master password", "device-ui-test-passphrase");
        confirmReplacement(activity); click(activity, "Restore and replace vault");
        awaitText(activity, "Edited test entry\nperson@example.test");
        try (VaultData restored = VaultData.unlock(new VaultStore(target).read(), "device-ui-test-passphrase".toCharArray())) {
            check(restored.entries.size() == 1 && "test-only-secret".equals(restored.entries.get(0).password()),
                    "Fresh installation restores exact test credentials using only the backup password");
        }
        check(keys.containsAlias("grounded.vault.device.v1"), "Restored vault gets a new device key");
        click(activity, "Lock vault now");
        runOnMainSync(activity::finish);
    }
    private void runChecks() throws Exception {
        Context target = getTargetContext();
        // Refuse before creating keys or writing any files in this package.
        check(!new VaultStore(target).exists(), "Device checks require a fresh test install");
        PackageInfo info = target.getPackageManager().getPackageInfo(target.getPackageName(), PackageManager.GET_PERMISSIONS);
        check(info.requestedPermissions == null || info.requestedPermissions.length == 0, "No permissions requested");
        check((info.applicationInfo.flags & ApplicationInfo.FLAG_ALLOW_BACKUP) == 0, "Backup disabled");
        File testRoot = new File(target.getNoBackupFilesDir(), "instrumentation-" + UUID.randomUUID());
        check(testRoot.mkdirs(), "Private test directory");
        Context isolated = new ContextWrapper(target) {
            @Override public File getNoBackupFilesDir() { return testRoot; }
        };
        VaultStore store = new VaultStore(isolated);
        char[] master = "instrumentation-only-passphrase".toCharArray();
        byte[] salt = VaultCrypto.salt(), key = VaultCrypto.derive(master, salt);
        try (VaultData data = new VaultData(key, salt, List.of(new VaultData.Entry(UUID.randomUUID().toString(),
                "Test site", "test-user", "test-secret", "example.test")))) {
            byte[] portable = data.encrypted(); store.write(portable);
            check(store.exists(), "Vault persisted");
            check(Arrays.equals(portable, new VaultStore(isolated).read()), "Keystore roundtrip across repository instances");
            byte[] disk = java.nio.file.Files.readAllBytes(new File(testRoot, "vault.bin").toPath());
            check(!Arrays.equals(portable, disk), "Device wrapping differs from portable backup");
            check(!new String(disk, java.nio.charset.StandardCharsets.ISO_8859_1).contains("test-secret"), "No plaintext secret on disk");
            try (VaultData imported = VaultData.unlock(portable, master)) {
                check(imported.entries.equals(data.entries), "Portable password restore");
            }
            byte[] before = store.read();
            boolean wrongRejected = false;
            try { VaultData.unlock(portable, "wrong".toCharArray()).close(); }
            catch (Exception expected) { wrongRejected = true; }
            check(wrongRejected, "Wrong password rejected");
            check(Arrays.equals(before, store.read()), "Failed authentication leaves original intact");
            android.util.AtomicFile atomic = new android.util.AtomicFile(new File(testRoot, "vault.bin"));
            FileOutputStream incomplete = atomic.startWrite(); incomplete.write(new byte[]{1, 2, 3}); atomic.failWrite(incomplete);
            check(Arrays.equals(before, store.read()), "Interrupted write rollback");
            disk[disk.length - 1] ^= 1;
            java.nio.file.Files.write(new File(testRoot, "vault.bin").toPath(), disk);
            boolean tamperRejected = false;
            try { store.read(); } catch (Exception expected) { tamperRejected = true; }
            check(tamperRejected, "Device ciphertext tampering rejected");
        } finally {
            VaultCrypto.wipe(key); Arrays.fill(master, '\0');
            File[] files = testRoot.listFiles(); if (files != null) for (File f : files) f.delete(); testRoot.delete();
        }
        // Never overwrite an existing user's vault when instrumentation is run manually.
        check(!new VaultStore(target).exists(), "UI checks require a fresh test install");
        Intent launch = target.getPackageManager().getLaunchIntentForPackage(target.getPackageName());
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK);
        Activity activity = startActivitySync(launch); waitForIdleSync();
        check((activity.getWindow().getAttributes().flags & WindowManager.LayoutParams.FLAG_SECURE) != 0, "Secure window");
        setField(activity, "Master password", "device-ui-test-passphrase");
        setField(activity, "Repeat master password", "device-ui-test-passphrase"); click(activity, "Create vault");
        awaitText(activity, "Add password");
        click(activity, "Auto-lock timing"); click(activity, "5 minutes — Relaxed");
        check(hasText(activity, "Locks when you leave and after 5 minutes without activity."), "Auto-lock choice is applied");
        click(activity, "Auto-lock timing"); click(activity, "1 minute — Very strict");
        clickByDescription(activity, "Cosmic Mode");
        AlertDialog cosmicDialog = awaitDialog(activity, "The frog is back!");
        runOnMainSync(() -> cosmicDialog.getButton(AlertDialog.BUTTON_POSITIVE).performClick()); waitForIdleSync();
        check(activity.getCurrentFocus() != null && "Cosmic Mode".contentEquals(activity.getCurrentFocus().getContentDescription()),
                "Cosmic Mode restores focus to its control");
        click(activity, "Add password"); setField(activity, "Title", "Device test entry");
        click(activity, "Generate password");
        runOnMainSync(() -> {
            for (View v : views(activity)) if (v instanceof EditText e && "Password".contentEquals(e.getContentDescription())) {
                check(e.length() == 20, "Local generator fills password field");
                check(e.getTransformationMethod() instanceof android.text.method.PasswordTransformationMethod,
                        "Generated password stays masked");
            }
        });
        setField(activity, "Password", "");
        runOnMainSync(() -> {
            for (View v : views(activity)) {
                if (v instanceof Spinner spinner && "Generated password length".contentEquals(spinner.getContentDescription()))
                    spinner.setSelection(3);
                if (v instanceof CheckBox box && "Include symbols".contentEquals(box.getText())) box.setChecked(false);
            }
        });
        click(activity, "Generate password");
        runOnMainSync(() -> {
            for (View v : views(activity)) if (v instanceof EditText e && "Password".contentEquals(e.getContentDescription())) {
                check(e.length() == 32, "Generator length selector is applied");
                check(!e.getText().toString().matches(".*[!@#$%&*?_-].*"), "Generator no-symbols option is applied");
            }
        });
        setField(activity, "Username / email", "person@example.test"); setField(activity, "Password", "test-only-secret");
        click(activity, "Save"); awaitText(activity, "Device test entry\nperson@example.test");
        click(activity, "Device test entry\nperson@example.test");
        check(!hasText(activity, "test-only-secret"), "Password hidden by default");
        click(activity, "Reveal for 10 seconds"); check(hasText(activity, "test-only-secret"), "Temporary reveal");
        click(activity, "Hide password now"); check(!hasText(activity, "test-only-secret"), "Reveal can be hidden immediately");
        click(activity, "Reveal for 10 seconds");
        long focusDeadline = android.os.SystemClock.elapsedRealtime() + 10_000;
        while (!activity.hasWindowFocus() && android.os.SystemClock.elapsedRealtime() < focusDeadline) Thread.sleep(100);
        check(activity.hasWindowFocus(), "Foreground window focus for clipboard test");
        ClipboardFailureFixture failedCopy = new ClipboardFailureFixture();
        runOnMainSync(() -> {
            SensitiveClipboard isolatedClipboard = new SensitiveClipboard(failedCopy);
            isolatedClipboard.copy("first-test-secret");
            failedCopy.denyNextWrite = true;
            boolean denied = false;
            try { isolatedClipboard.copy("replacement-test-secret"); }
            catch (SecurityException expected) { denied = true; }
            check(denied && "first-test-secret".contentEquals(failedCopy.clip.getItemAt(0).getText()),
                    "Denied clipboard replacement preserves the previous clip");
            ClipboardFailureFixture cleanupFailure = new ClipboardFailureFixture();
            SensitiveClipboard guardedClipboard = new SensitiveClipboard(cleanupFailure);
            guardedClipboard.copy("cleanup-test-secret");
            cleanupFailure.failNextRead = true;
            guardedClipboard.clearOwned();
            check(cleanupFailure.clip != null, "Unexpected clipboard read failure is contained");
            cleanupFailure.failNextClear = true;
            guardedClipboard.clearOwned();
            check(cleanupFailure.clip != null, "Unexpected clipboard clear failure is contained");
            guardedClipboard.clearOwned();
            check(cleanupFailure.clip == null, "Clipboard cleanup retries after runtime failure");
        });
        click(activity, "Copy password");
        boolean genericClipboard = isGenericEmulator();
        if (!genericClipboard) {
            boolean[] sensitive = {false};
            runOnMainSync(() -> {
                ClipboardManager clipboard = target.getSystemService(ClipboardManager.class);
                android.content.ClipDescription description = clipboard.getPrimaryClipDescription();
                sensitive[0] = description != null && description.getExtras() != null
                        && description.getExtras().getBoolean("android.content.extra.IS_SENSITIVE");
            });
            check(sensitive[0], "Sensitive clipboard flag");
            long expiryDeadline = android.os.SystemClock.elapsedRealtime() + 25_000;
            boolean[] hasClip = {true};
            while (hasClip[0] && android.os.SystemClock.elapsedRealtime() < expiryDeadline) {
                Thread.sleep(100);
                runOnMainSync(() -> hasClip[0] = target.getSystemService(ClipboardManager.class).hasPrimaryClip());
            }
            check(!hasClip[0], "Clipboard expires while foregrounded");
        } else {
            System.out.println("SKIP: generic emulator clipboard metadata and expiry observation; verify on a physical device");
            // Still wait for the isolated failure fixture's production timeout so
            // its previous-cleanup-deadline regression check remains meaningful.
            Thread.sleep(21_000);
        }
        runOnMainSync(() -> check(failedCopy.clip == null,
                "Denied clipboard replacement preserves the previous cleanup deadline"));
        check(!hasText(activity, "test-only-secret"), "Revealed password is masked again automatically");
        click(activity, "Copy password");
        click(activity, "Lock vault now"); awaitText(activity, "Unlock");
        if (!genericClipboard)
            runOnMainSync(() -> check(!target.getSystemService(ClipboardManager.class).hasPrimaryClip(), "Manual lock clears copied secret"));
        setField(activity, "Master password", "device-ui-test-passphrase"); click(activity, "Unlock");
        awaitText(activity, "Add password");
        setField(activity, "Search title, username or website", "does-not-exist"); awaitText(activity, "No matching entries.");
        setField(activity, "Search title, username or website", "DEVICE");
        awaitText(activity, "Device test entry\nperson@example.test");
        click(activity, "Device test entry\nperson@example.test"); click(activity, "Edit");
        setField(activity, "Title", "Edited test entry"); click(activity, "Save");
        awaitText(activity, "Edited test entry\nperson@example.test");

        // Supply a test document at the picker boundary; exercise production provider I/O.
        android.net.Uri document = android.net.Uri.parse("content://app.grounded.password.test.documents/backup.gpv");
        byte[] portable = new VaultStore(target).read();
        click(activity, "Lock vault now");
        backupController(activity).setPendingExport(portable);
        runOnMainSync(() -> ((MainActivity) activity).onActivityResult(12, Activity.RESULT_OK, new Intent().setData(document)));
        awaitText(activity, "Encrypted backup exported. Keep it and your master password safe.");
        try (android.database.Cursor mode = target.getContentResolver().query(document, null, null, null, null)) {
            check(mode != null && mode.moveToFirst() && "wt".equals(mode.getString(0)),
                    "Export requests a truncating provider stream");
        }
        byte[] backup;
        try (InputStream in = target.getContentResolver().openInputStream(document)) { backup = VaultStore.readBounded(in, VaultCrypto.MAX_FILE_BYTES); }
        try (VaultData restored = VaultData.unlock(backup, "device-ui-test-passphrase".toCharArray())) {
            check(restored.entries.get(0).title().equals("Edited test entry"), "Exported document restores with password only");
        }
        setField(activity, "Master password", "device-ui-test-passphrase"); click(activity, "Unlock"); awaitText(activity, "Add password");
        click(activity, "Edited test entry\nperson@example.test"); click(activity, "Delete");
        java.lang.reflect.Field dialogField = MainActivity.class.getDeclaredField("dialog"); dialogField.setAccessible(true);
        AlertDialog deleteDialog = (AlertDialog) dialogField.get(activity);
        check((deleteDialog.getWindow().getAttributes().flags & WindowManager.LayoutParams.FLAG_SECURE) != 0,
                "Dialog window is explicitly secure");
        runOnMainSync(() -> deleteDialog.getButton(AlertDialog.BUTTON_POSITIVE).performClick());
        awaitText(activity, "No passwords yet. Tap Add password to get started.");
        click(activity, "Lock vault now");
        runOnMainSync(() -> ((MainActivity) activity).onActivityResult(11, Activity.RESULT_OK, new Intent().setData(document)));
        awaitText(activity, "Restore and replace vault"); setField(activity, "Backup master password", "wrong");
        confirmReplacement(activity); click(activity, "Restore and replace vault");
        awaitText(activity, "The backup could not be authenticated. The password may be wrong, or the backup may be damaged. Your existing vault was not replaced.");
        try (VaultData retained = VaultData.unlock(new VaultStore(target).read(), "device-ui-test-passphrase".toCharArray())) {
            check(retained.entries.isEmpty(), "Wrong import password preserves current vault");
        }
        runOnMainSync(() -> ((MainActivity) activity).onActivityResult(11, Activity.RESULT_OK, new Intent().setData(document)));
        awaitText(activity, "Restore and replace vault"); setField(activity, "Backup master password", "device-ui-test-passphrase");
        confirmReplacement(activity); click(activity, "Restore and replace vault");
        awaitText(activity, "Edited test entry\nperson@example.test");
        check(hasText(activity, "Edited test entry\nperson@example.test"), "Confirmed import replaces vault");
        runOnMainSync(() -> callActivityOnPause(activity));
        check(hasText(activity, "Unlock"), "Background locks vault");
        check(!hasText(activity, "Edited test entry\nperson@example.test"), "Background removes entries from view");
        runOnMainSync(() -> callActivityOnResume(activity));
        runOnMainSync(activity::finish);
        checkExportRecreation(launch, document, backup);
    }
    private static final class ClipboardFailureFixture implements SensitiveClipboard.Access {
        ClipData clip;
        boolean denyNextWrite;
        boolean failNextRead;
        boolean failNextClear;
        public void setPrimaryClip(ClipData value) {
            if (denyNextWrite) throw new SecurityException("injected denial");
            clip = value;
        }
        public android.content.ClipDescription getPrimaryClipDescription() {
            if (failNextRead) { failNextRead = false; throw new IllegalStateException("injected read failure"); }
            return clip == null ? null : clip.getDescription();
        }
        public void clearPrimaryClip() {
            if (failNextClear) { failNextClear = false; throw new IllegalStateException("injected clear failure"); }
            clip = null;
        }
    }
    private boolean isGenericEmulator() {
        String hardware = android.os.Build.HARDWARE == null ? "" : android.os.Build.HARDWARE;
        String model = android.os.Build.MODEL == null ? "" : android.os.Build.MODEL;
        return hardware.contains("ranchu") || hardware.contains("goldfish") || model.contains("sdk_gphone");
    }
    private void checkExportRecreation(Intent launch, android.net.Uri document, byte[] backup) throws Exception {
        Activity original = startActivitySync(launch); waitForIdleSync();
        byte[] pending = backup.clone();
        runOnMainSync(() -> backupController(original).setPendingExport(pending));
        ActivityMonitor monitor = addMonitor(MainActivity.class.getName(), null, false);
        runOnMainSync(original::recreate);
        Activity recreated = waitForMonitorWithTimeout(monitor, 10_000);
        removeMonitor(monitor);
        check(recreated != null && recreated != original, "Android recreates the export activity");
        waitForIdleSync();
        check(Arrays.equals(pending, backup) && backupController(recreated).hasPendingExport(),
                "Activity recreation retains only the encrypted pending export");
        check(hasText(recreated, "Unlock"), "Recreated export activity remains locked");
        runOnMainSync(() -> ((MainActivity) recreated).onActivityResult(12, Activity.RESULT_OK, new Intent().setData(document)));
        awaitText(recreated, "Encrypted backup exported. Keep it and your master password safe.");
        byte[] restored;
        try (InputStream in = getTargetContext().getContentResolver().openInputStream(document)) {
            restored = VaultStore.readBounded(in, VaultCrypto.MAX_FILE_BYTES);
        }
        check(Arrays.equals(restored, backup), "Recreated activity exports the complete encrypted backup");
        // Process death loses the in-memory snapshot. Its returned picker result must explain the failure.
        runOnMainSync(() -> ((MainActivity) recreated).onActivityResult(12, Activity.RESULT_OK, new Intent().setData(document)));
        awaitText(recreated, "Export was interrupted. Unlock and export again. The selected file may be empty; do not rely on it as a backup.");
        check(!backupController(recreated).hasPendingExport(), "Missing export is reported without creating secret saved state");
        runOnMainSync(recreated::finish);
    }
    private List<View> views(Activity activity) {
        List<View> result = new ArrayList<>(); collect(activity.getWindow().getDecorView(), result); return result;
    }
    private BackupController backupController(Activity activity) {
        try {
            java.lang.reflect.Field field = MainActivity.class.getDeclaredField("backups"); field.setAccessible(true);
            return (BackupController) field.get(activity);
        } catch (Exception e) { throw new AssertionError(e); }
    }
    private void clickByDescription(Activity activity, String description) {
        runOnMainSync(() -> {
            activity.onUserInteraction();
            for (View v : views(activity)) if (v.getContentDescription() != null
                    && description.contentEquals(v.getContentDescription())) { v.performClick(); return; }
            throw new AssertionError("Missing control: " + description);
        }); waitForIdleSync();
    }
    private AlertDialog awaitDialog(Activity activity, String title) throws Exception {
        java.lang.reflect.Field field = MainActivity.class.getDeclaredField("dialog"); field.setAccessible(true);
        long deadline = android.os.SystemClock.elapsedRealtime() + 30_000;
        while (android.os.SystemClock.elapsedRealtime() < deadline) {
            AlertDialog shown = (AlertDialog) field.get(activity);
            if (shown != null && shown.isShowing() && shown.getWindow() != null
                    && title.contentEquals(shown.getWindow().getDecorView().findViewById(
                    getTargetContext().getResources().getIdentifier("alertTitle", "id", "android")) instanceof TextView heading
                    ? heading.getText() : "")) return shown;
            Thread.sleep(100);
        }
        throw new AssertionError("Timed out waiting for dialog " + title);
    }
    private void collect(View v, List<View> result) {
        result.add(v); if (v instanceof ViewGroup group) for (int i = 0; i < group.getChildCount(); i++) collect(group.getChildAt(i), result);
    }
    private boolean hasText(Activity activity, String text) {
        boolean[] result = {false};
        runOnMainSync(() -> { for (View v : views(activity)) if (v instanceof TextView t && text.contentEquals(t.getText())) result[0] = true; });
        return result[0];
    }
    private void click(Activity activity, String label) {
        runOnMainSync(() -> {
            activity.onUserInteraction();
            for (View v : views(activity)) if (v instanceof Button b && label.contentEquals(b.getText())) { b.performClick(); return; }
            throw new AssertionError("Missing button: " + label);
        }); waitForIdleSync();
    }
    private void setField(Activity activity, String label, String value) {
        runOnMainSync(() -> {
            activity.onUserInteraction();
            for (View v : views(activity)) if (v instanceof EditText e && label.contentEquals(e.getContentDescription())) { e.setText(value); return; }
            throw new AssertionError("Missing field: " + label);
        }); waitForIdleSync();
    }
    private void awaitText(Activity activity, String text) throws Exception {
        // Host contention and first-boot Keystore initialization can be slow in CI/emulators.
        long deadline = android.os.SystemClock.elapsedRealtime() + 120_000;
        while (android.os.SystemClock.elapsedRealtime() < deadline) {
            if (hasText(activity, text)) { checks++; return; } Thread.sleep(100);
        }
        throw new AssertionError("Timed out waiting for " + text);
    }
    private void confirmReplacement(Activity activity) {
        runOnMainSync(() -> { for (View v : views(activity)) if (v instanceof CheckBox box) box.setChecked(true); });
    }
}

package app.grounded.password;

import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.os.PersistableBundle;
import android.os.SystemClock;
import java.util.UUID;

/** Best-effort OS clipboard cleanup; Android may deny access while backgrounded. */
final class SensitiveClipboard {
    private static SensitiveClipboard instance;
    static synchronized SensitiveClipboard get(Context context) {
        if (instance == null) instance = new SensitiveClipboard(context.getApplicationContext());
        return instance;
    }
    interface Access {
        void setPrimaryClip(ClipData clip);
        android.content.ClipDescription getPrimaryClipDescription();
        void clearPrimaryClip();
    }
    private final Access manager;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private String token;
    private long expires;
    private final Runnable cleanup = () -> clearOwned();
    SensitiveClipboard(Context context) {
        ClipboardManager system = context.getSystemService(ClipboardManager.class);
        manager = new Access() {
            public void setPrimaryClip(ClipData clip) { system.setPrimaryClip(clip); }
            public android.content.ClipDescription getPrimaryClipDescription() { return system.getPrimaryClipDescription(); }
            public void clearPrimaryClip() { system.clearPrimaryClip(); }
        };
    }
    SensitiveClipboard(Access access) { manager = access; }
    /** Returns whether the current foreground activity can confirm the copied item. */
    boolean copy(String value) {
        // Do not disturb the existing expiry until Android has accepted the
        // replacement. A denied setPrimaryClip() must not leave an earlier
        // password without its scheduled cleanup.
        String newToken = "Frog Secure PW Keeper " + UUID.randomUUID();
        ClipData clip = ClipData.newPlainText(newToken, value);
        PersistableBundle extras = new PersistableBundle();
        extras.putBoolean("android.content.extra.IS_SENSITIVE", true);
        clip.getDescription().setExtras(extras);
        manager.setPrimaryClip(clip);
        handler.removeCallbacks(cleanup);
        token = newToken;
        expires = SystemClock.elapsedRealtime() + 20_000;
        handler.postDelayed(cleanup, 20_000);
        // Keep the ownership token and expiry even when Android does not let us
        // immediately read the clipboard. A later focused retry can still
        // clear an item that was accepted despite being unverifiable here.
        return ownsPrimaryClip();
    }
    /** Call after the activity actually has window focus, when Android allows clipboard access again. */
    void onForeground() {
        if (token == null) return;
        long remaining = expires - SystemClock.elapsedRealtime();
        if (remaining <= 0) clearOwned();
        else {
            handler.removeCallbacks(cleanup);
            handler.postDelayed(cleanup, remaining);
        }
    }
    private boolean ownsPrimaryClip() {
        try {
            android.content.ClipDescription description = manager.getPrimaryClipDescription();
            return description != null && description.getLabel() != null
                    && token != null && token.contentEquals(description.getLabel());
        } catch (RuntimeException ignored) {
            return false;
        }
    }
    void clearOwned() {
        if (token == null) return;
        // Manual lock must stay due even if Android denies clipboard access now.
        expires = 0;
        try {
            android.content.ClipDescription description = manager.getPrimaryClipDescription();
            // Null can mean access denied in background. Retain token for foreground retry.
            if (description == null) return;
            if (description.getLabel() != null && token.contentEquals(description.getLabel())) manager.clearPrimaryClip();
            token = null;
            handler.removeCallbacks(cleanup);
        } catch (RuntimeException ignored) { /* Retry on return to the app. */ }
    }
}

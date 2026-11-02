package app.grounded.password;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.Intent;
import android.graphics.Color;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.text.Editable;
import android.text.InputFilter;
import android.text.InputType;
import android.text.TextWatcher;
import android.view.View;
import android.view.WindowManager;
import android.view.inputmethod.EditorInfo;
import android.widget.*;
import java.util.*;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/** Phase 1 native UI. Secrets are never put in intents, saved state, preferences or logs. */
public final class MainActivity extends Activity {
    private static final int IMPORT = 11, EXPORT = 12;
    private static final int MAX_CONTENT_WIDTH_DP = 720;
    private static final int ENTRY_PAGE_SIZE = 100;
    private static final long SEARCH_DELAY_MS = 150;
    private static final String EXPORT_INTERRUPTED = "Export was interrupted. Unlock and export again. The selected file may be empty; do not rely on it as a backup.";
    private static final String EXPORT_PENDING_STATE = "export_pending";
    private final Handler handler = new Handler(Looper.getMainLooper());
    // Serialize vault I/O across activity recreation as well as within one screen.
    private static final ExecutorService worker = Executors.newSingleThreadExecutor();
    private final List<EditText> fields = new ArrayList<>();
    private final List<TextView> secretViews = new ArrayList<>();
    private Runnable pendingMask;
    private final Runnable idleLock = () -> lock(true);
    private static final String SETTINGS = "non_secret_settings";
    private static final String AUTO_LOCK_MINUTES = "auto_lock_minutes";
    private VaultController vault;
    private BackupController backups;
    private SensitiveClipboard clipboard;
    private LinearLayout page;
    private AlertDialog dialog;
    private CosmicView cosmic;
    private View cosmicSource;
    private View cosmicReturnFocus;
    private int savedSystemUi, savedAccessibility;
    private boolean foreground, busy;
    private int generation;

    @Override public void onCreate(Bundle state) {
        super.onCreate(null);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_SECURE);
        if (android.os.Build.VERSION.SDK_INT >= 33)
            getOnBackInvokedDispatcher().registerOnBackInvokedCallback(
                    android.window.OnBackInvokedDispatcher.PRIORITY_DEFAULT, this::handleBack);
        vault = new VaultController(this);
        backups = new BackupController();
        clipboard = SensitiveClipboard.get(getApplicationContext());
        backups.restoreRetained(getLastNonConfigurationInstance());
        showLocked(!backups.hasPendingExport() && state != null && state.getBoolean(EXPORT_PENDING_STATE)
                ? EXPORT_INTERRUPTED : "");
    }
    @Override protected void onResume() {
        super.onResume(); foreground = true; clipboard.onForeground(); resetIdle();
    }
    @Override public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        // Android may deny clipboard access during onResume. Window focus is the
        // reliable point to retry a timeout that elapsed while the user pasted.
        if (hasFocus && clipboard != null) clipboard.onForeground();
    }
    @Override protected void onPause() {
        foreground = false;
        // The copied item gets a short paste window. Manual/idle lock clears it immediately.
        lock(false);
        super.onPause();
    }
    @Override protected void onDestroy() {
        lock(true);
        // The system can recreate this activity while its document picker is
        // open. Keep only the already password-encrypted export in memory so
        // its result can still be written. Process death still safely cancels.
        backups.clearAll(isChangingConfigurations());
        super.onDestroy();
    }
    @Override public Object onRetainNonConfigurationInstance() {
        return backups.retainedExport();
    }
    @Override public void onUserInteraction() { super.onUserInteraction(); resetIdle(); }
    @Override protected void onSaveInstanceState(Bundle state) {
        // Only an operation flag, never view contents, passwords, keys or ciphertext.
        state.putBoolean(EXPORT_PENDING_STATE, backups.hasPendingExport());
    }
    // API 33+ uses the native dispatcher above. This override is only for legacy phones.
    @android.annotation.SuppressLint("GestureBackNavigation")
    @Override public void onBackPressed() { handleBack(); }
    private void handleBack() { if (cosmic != null) return; if (vault.session() != null) lock(true); else finish(); }

    @Override public boolean dispatchTouchEvent(android.view.MotionEvent event) {
        return cosmic != null || super.dispatchTouchEvent(event);
    }
    @Override public boolean dispatchKeyEvent(android.view.KeyEvent event) {
        return cosmic != null || super.dispatchKeyEvent(event);
    }

    private void startCosmic(View returnFocus) {
        if (busy || cosmic != null || !foreground) return;
        cosmicReturnFocus = returnFocus;
        android.view.inputmethod.InputMethodManager keyboard = getSystemService(android.view.inputmethod.InputMethodManager.class);
        keyboard.hideSoftInputFromWindow(page.getWindowToken(), 0);
        android.view.ViewGroup content = findViewById(android.R.id.content);
        cosmicSource = content.getChildAt(0);
        android.util.TypedValue color = new android.util.TypedValue();
        getTheme().resolveAttribute(android.R.attr.colorBackground, color, true);
        final int cosmicGeneration = generation;
        cosmic = new CosmicView(this, cosmicSource, color.data, () -> {
            if (cosmic == null || cosmicGeneration != generation) return;
            stopCosmic();
            if (!foreground || isDestroyed()) return;
            resetIdle();
            dialog = new AlertDialog.Builder(this).setTitle("The frog is back!")
                    .setMessage("The black hole was fun for us, but certainly not for the frog! Do not worry. It was just for fun. Your passwords are completely safe and unharmed.")
                    .setPositiveButton("OK", (d, w) -> { resetIdle(); restoreCosmicAccessibilityFocus(); })
                    .setCancelable(false).create();
            showSecureDialog();
        });
        savedAccessibility = cosmicSource.getImportantForAccessibility();
        cosmicSource.setImportantForAccessibility(View.IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS);
        cosmicSource.setAlpha(0);
        savedSystemUi = getWindow().getDecorView().getSystemUiVisibility();
        getWindow().getDecorView().setSystemUiVisibility(savedSystemUi | View.SYSTEM_UI_FLAG_FULLSCREEN
                | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                | View.SYSTEM_UI_FLAG_LAYOUT_STABLE | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION);
        content.addView(cosmic, new android.view.ViewGroup.LayoutParams(-1, -1));
        resetIdle();
    }
    private void stopCosmic() {
        if (cosmic == null) return;
        cosmic.cancel();
        ((android.view.ViewGroup) cosmic.getParent()).removeView(cosmic);
        cosmic = null;
        cosmicSource.setAlpha(1);
        cosmicSource.setImportantForAccessibility(savedAccessibility);
        cosmicSource = null;
        getWindow().getDecorView().setSystemUiVisibility(savedSystemUi);
    }
    private void restoreCosmicAccessibilityFocus() {
        View target = cosmicReturnFocus;
        cosmicReturnFocus = null;
        if (target == null || !target.isAttachedToWindow()) return;
        target.post(() -> {
            if (!target.isAttachedToWindow()) return;
            target.requestFocus();
            target.sendAccessibilityEvent(android.view.accessibility.AccessibilityEvent.TYPE_VIEW_ACCESSIBILITY_FOCUSED);
        });
    }

    private void resetIdle() {
        handler.removeCallbacks(idleLock);
        if (vault.session() != null && foreground) handler.postDelayed(idleLock, autoLockMillis());
    }
    private int autoLockMinutes() {
        int minutes = getSharedPreferences(SETTINGS, MODE_PRIVATE).getInt(AUTO_LOCK_MINUTES, 1);
        return minutes == 2 || minutes == 3 || minutes == 5 ? minutes : 1;
    }
    private long autoLockMillis() { return autoLockMinutes() * 60_000L; }
    private void lock(boolean clearClipboard) {
        stopCosmic();
        generation++;
        handler.removeCallbacks(idleLock);
        vault.lock();
        backups.clearImport();
        if (dialog != null) { dialog.dismiss(); dialog = null; }
        if (clearClipboard) clipboard.clearOwned();
        showLocked("");
    }
    private int dp(int value) { return Math.round(value * getResources().getDisplayMetrics().density); }
    private void newPage(String title, String subtitle) { newPage(title, subtitle, null, true, false, false); }
    private void newPage(String title, String subtitle, Runnable fixedClose) { newPage(title, subtitle, fixedClose, true, false, false); }
    private void newPage(String title, String subtitle, Runnable fixedClose, boolean showSupport) {
        newPage(title, subtitle, fixedClose, showSupport, false, false);
    }
    /** A scrolling page with optional fixed support, Cosmic Mode, and privacy controls. */
    private void newPage(String title, String subtitle, Runnable fixedClose, boolean showSupport,
                         boolean showCosmic, boolean showPrivacyHelp) {
        if (pendingMask != null) { handler.removeCallbacks(pendingMask); pendingMask = null; }
        for (TextView view : secretViews) view.setText("");
        secretViews.clear();
        for (EditText field : fields) field.setText("");
        fields.clear();
        ScrollView scroll = new ScrollView(this); scroll.setFillViewport(true);
        scroll.setSaveEnabled(false);
        LinearLayout columnHolder = new LinearLayout(this);
        columnHolder.setOrientation(LinearLayout.VERTICAL);
        columnHolder.setGravity(android.view.Gravity.CENTER_HORIZONTAL);
        page = new LinearLayout(this); page.setOrientation(LinearLayout.VERTICAL);
        final LinearLayout contentPage = page;
        int bottomPadding = showSupport || showCosmic ? (fixedClose == null ? 96 : 168) : (fixedClose == null ? 24 : 96);
        page.setPadding(dp(24), dp(24), dp(24), dp(bottomPadding));
        page.setImportantForAutofill(View.IMPORTANT_FOR_AUTOFILL_NO_EXCLUDE_DESCENDANTS);
        page.setSaveFromParentEnabled(false);
        if (android.os.Build.VERSION.SDK_INT >= 30)
            page.setImportantForContentCapture(View.IMPORTANT_FOR_CONTENT_CAPTURE_NO_EXCLUDE_DESCENDANTS);
        columnHolder.addView(contentPage, new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT));
        // A comfortable measure on tablets/Chromebooks while remaining full-width on phones and cover displays.
        columnHolder.addOnLayoutChangeListener((view, left, top, right, bottom, oldLeft, oldTop, oldRight, oldBottom) -> {
            int width = Math.min(right - left, dp(MAX_CONTENT_WIDTH_DP));
            LinearLayout.LayoutParams params = (LinearLayout.LayoutParams) contentPage.getLayoutParams();
            if (params.width != width) { params.width = width; contentPage.setLayoutParams(params); }
        });
        scroll.addView(columnHolder, new ScrollView.LayoutParams(ScrollView.LayoutParams.MATCH_PARENT,
                ScrollView.LayoutParams.WRAP_CONTENT));
        if (android.os.Build.VERSION.SDK_INT >= 30) scroll.setOnApplyWindowInsetsListener((view, insets) -> {
            android.graphics.Insets bars = insets.getInsets(android.view.WindowInsets.Type.systemBars()
                    | android.view.WindowInsets.Type.ime());
            view.setPadding(bars.left, bars.top, bars.right, bars.bottom); return insets;
        });
        if (android.os.Build.VERSION.SDK_INT < 30) {
            scroll.setOnApplyWindowInsetsListener(null); scroll.setFitsSystemWindows(true);
        }
        FrameLayout root = new FrameLayout(this);
        root.setImportantForAutofill(View.IMPORTANT_FOR_AUTOFILL_NO_EXCLUDE_DESCENDANTS);
        if (android.os.Build.VERSION.SDK_INT >= 30)
            root.setImportantForContentCapture(View.IMPORTANT_FOR_CONTENT_CAPTURE_NO_EXCLUDE_DESCENDANTS);
        if (android.os.Build.VERSION.SDK_INT >= 34)
            root.setAccessibilityDataSensitive(View.ACCESSIBILITY_DATA_SENSITIVE_YES);
        root.addView(scroll, new FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT));
        Button close = null;
        if (fixedClose != null) {
            close = new Button(this); close.setText("Close"); close.setAllCaps(false);
            close.setMinHeight(dp(52)); close.setOnClickListener(v -> { if (!busy) fixedClose.run(); });
            FrameLayout.LayoutParams closeParams = new FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.WRAP_CONTENT, android.view.Gravity.BOTTOM);
            closeParams.setMargins(dp(24), 0, dp(24), dp(16)); close.setLayoutParams(closeParams);
            root.addView(close);
        }
        FrogHeartView heart = null;
        if (showSupport) {
            heart = new FrogHeartView(this); heart.setOnClickListener(v -> { if (!busy) showSupport(); });
            FrameLayout.LayoutParams heartParams = new FrameLayout.LayoutParams(dp(56), dp(56),
                    android.view.Gravity.BOTTOM | android.view.Gravity.END);
            heartParams.setMargins(0, 0, dp(18), dp(fixedClose == null ? 18 : 86)); heart.setLayoutParams(heartParams);
            root.addView(heart);
        }
        Button privacyHelp = null;
        if (showPrivacyHelp) {
            privacyHelp = new Button(this); privacyHelp.setText("Privacy & help"); privacyHelp.setAllCaps(false);
            privacyHelp.setMinHeight(dp(52)); privacyHelp.setOnClickListener(v -> { if (!busy) showHelp(); });
            FrameLayout.LayoutParams privacyParams = new FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.WRAP_CONTENT, android.view.Gravity.BOTTOM | android.view.Gravity.START);
            privacyParams.setMargins(dp(18), 0, dp(showCosmic ? 162 : 18), dp(fixedClose == null ? 14 : 82));
            privacyHelp.setLayoutParams(privacyParams);
            root.addView(privacyHelp);
        }
        CosmicModeButton cosmicButton = null;
        if (showCosmic) {
            cosmicButton = new CosmicModeButton(this);
            cosmicButton.setOnClickListener(v -> { if (!busy) startCosmic(v); });
            FrameLayout.LayoutParams cosmicParams = new FrameLayout.LayoutParams(dp(76), dp(58),
                    android.view.Gravity.BOTTOM | android.view.Gravity.END);
            cosmicParams.setMargins(0, 0, dp(showSupport ? 78 : 18), dp(fixedClose == null ? 14 : 82));
            cosmicButton.setLayoutParams(cosmicParams);
            root.addView(cosmicButton);
        }
        final Button fixedButton = close;
        final FrogHeartView supportHeart = heart;
        final Button privacyControl = privacyHelp;
        final CosmicModeButton cosmicControl = cosmicButton;
        if (android.os.Build.VERSION.SDK_INT >= 30) root.setOnApplyWindowInsetsListener((view, insets) -> {
            android.graphics.Insets bars = insets.getInsets(android.view.WindowInsets.Type.systemBars());
            if (fixedButton != null) {
                FrameLayout.LayoutParams params = (FrameLayout.LayoutParams) fixedButton.getLayoutParams();
                params.bottomMargin = dp(16) + bars.bottom; fixedButton.setLayoutParams(params);
            }
            if (supportHeart != null) {
                FrameLayout.LayoutParams params = (FrameLayout.LayoutParams) supportHeart.getLayoutParams();
                params.bottomMargin = dp((fixedClose == null ? 18 : 86)) + bars.bottom; supportHeart.setLayoutParams(params);
            }
            if (privacyControl != null) {
                FrameLayout.LayoutParams params = (FrameLayout.LayoutParams) privacyControl.getLayoutParams();
                params.bottomMargin = dp((fixedClose == null ? 14 : 82)) + bars.bottom;
                privacyControl.setLayoutParams(params);
            }
            if (cosmicControl != null) {
                FrameLayout.LayoutParams params = (FrameLayout.LayoutParams) cosmicControl.getLayoutParams();
                params.bottomMargin = dp((fixedClose == null ? 14 : 82)) + bars.bottom;
                cosmicControl.setLayoutParams(params);
            }
            return insets;
        });
        // Keep scrolling content above bottom controls even when large text or a
        // landscape window makes those controls taller than the nominal padding.
        root.addOnLayoutChangeListener((view, left, top, right, bottom, oldLeft, oldTop, oldRight, oldBottom) -> {
            int overlayTop = root.getHeight();
            if (fixedButton != null) overlayTop = Math.min(overlayTop, fixedButton.getTop());
            if (supportHeart != null) overlayTop = Math.min(overlayTop, supportHeart.getTop());
            if (privacyControl != null) overlayTop = Math.min(overlayTop, privacyControl.getTop());
            if (cosmicControl != null) overlayTop = Math.min(overlayTop, cosmicControl.getTop());
            FrameLayout.LayoutParams scrollParams = (FrameLayout.LayoutParams) scroll.getLayoutParams();
            int requiredInset = Math.max(0, root.getHeight() - overlayTop);
            if (scrollParams.bottomMargin != requiredInset) {
                scrollParams.bottomMargin = requiredInset;
                scroll.setLayoutParams(scrollParams);
            }
        });
        setContentView(root);
        LinearLayout titleRow = new LinearLayout(this);
        titleRow.setOrientation(LinearLayout.HORIZONTAL);
        titleRow.setGravity(android.view.Gravity.CENTER_VERTICAL);
        TextView heading = new TextView(this);
        heading.setText(title);
        heading.setTextSize(28);
        heading.setAccessibilityHeading(true);
        heading.setTextColor(Color.rgb(26, 67, 51));
        heading.setPadding(0, dp(8), 0, dp(8));
        heading.setLayoutParams(new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1));
        titleRow.addView(heading);
        VaultMascotView mascot = new VaultMascotView(this);
        mascot.setPadding(dp(4), 0, 0, 0);
        titleRow.addView(mascot, new LinearLayout.LayoutParams(dp(64), dp(56)));
        page.addView(titleRow);
        if (!subtitle.isEmpty()) text(subtitle);
    }
    private TextView text(String value) {
        TextView v = new TextView(this); v.setText(value); v.setTextSize(16);
        v.setPadding(0, dp(8), 0, dp(8)); v.setSaveEnabled(false); page.addView(v); return v;
    }
    private void hint(String value) {
        TextView v = new TextView(this); v.setText(value); v.setTextSize(14);
        v.setTextColor(Color.rgb(82, 98, 91)); v.setPadding(0, 0, 0, dp(8));
        v.setSaveEnabled(false); page.addView(v);
    }
    private Button button(String label, Runnable action) { return button(page, label, action); }
    private Button button(LinearLayout parent, String label, Runnable action) {
        Button b = new Button(this); b.setText(label); b.setAllCaps(false); b.setMinHeight(dp(52));
        b.setOnClickListener(v -> { if (!busy) { resetIdle(); action.run(); } }); parent.addView(b); return b;
    }
    private EditText field(String label, boolean password, String initial) { return field(label, password, initial, ""); }
    private EditText field(String label, boolean password, String initial, String fieldHint) {
        TextView labelView = text(label);
        EditText input = new EditText(this);
        input.setId(View.generateViewId()); labelView.setLabelFor(input.getId());
        input.setSingleLine(true); input.setTextSize(18); input.setMinHeight(dp(52));
        input.setInputType(InputType.TYPE_CLASS_TEXT | (password ? InputType.TYPE_TEXT_VARIATION_PASSWORD
                : InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS));
        input.setImeOptions(EditorInfo.IME_FLAG_NO_PERSONALIZED_LEARNING);
        input.setImportantForAutofill(View.IMPORTANT_FOR_AUTOFILL_NO);
        input.setSaveEnabled(false); input.setSaveFromParentEnabled(false);
        input.setFilters(new InputFilter[]{new InputFilter.LengthFilter(4096)});
        input.setContentDescription(label); input.setText(initial);
        input.addTextChangedListener(new TextWatcher() {
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {}
            public void onTextChanged(CharSequence s, int start, int before, int count) {
                // IME and accessibility edits do not always call Activity.onUserInteraction.
                if (input.hasFocus()) resetIdle();
            }
            public void afterTextChanged(Editable s) {}
        });
        fields.add(input); page.addView(input);
        if (!fieldHint.isEmpty()) hint(fieldHint);
        return input;
    }
    private void showSecureDialog() {
        if (dialog.getWindow() != null) dialog.getWindow().addFlags(WindowManager.LayoutParams.FLAG_SECURE);
        dialog.show();
    }
    private char[] password(EditText field) {
        Editable editable = field.getText(); char[] value = new char[editable.length()];
        editable.getChars(0, editable.length(), value, 0); field.setText(""); return value;
    }
    private void message(String value) { Toast.makeText(this, value, Toast.LENGTH_LONG).show(); }

    private void showLocked(String status) {
        boolean exists = vault.exists();
        newPage("Frog Secure PW Keeper", "Free. Simple. Respectful.\nYour offline password safe.", null, true, true, true);
        text(exists ? "Unlock your vault" : "Create your vault");
        if (!status.isEmpty()) text(status);
        if (busy) { text("Finishing secure operation…"); page.addView(new ProgressBar(this)); return; }
        if (!exists) text("Use a unique passphrase of 16 or more characters when you can. The minimum is 12 characters. There is no password reset. "
                + "If you forget it, your vault cannot be recovered. If this phone is lost, reset or damaged, "
                + "you need a manual encrypted backup to restore your passwords.");
        EditText master = field("Master password", true, "", "Never stored or sent. It unlocks this vault on this device.");
        EditText confirm = exists ? null : field("Repeat master password", true, "", "Enter the same passphrase again to prevent a typing mistake.");
        button(exists ? "Unlock" : "Create vault", () -> {
            char[] pass = password(master);
            if (!exists) {
                char[] repeated = password(confirm);
                boolean valid = pass.length >= 12 && Arrays.equals(pass, repeated);
                Arrays.fill(repeated, '\0');
                if (!valid) { Arrays.fill(pass, '\0'); message("Use at least 12 characters and enter the same password twice. A unique 16+ character passphrase is recommended."); return; }
            }
            authenticate(pass, !exists, null);
        });
        button("Import encrypted backup", this::chooseImport);
    }

    private void authenticate(char[] pass, boolean create, byte[] imported) {
        final int ticket = generation;
        busy = true; showLocked("Working securely…");
        worker.execute(() -> {
            VaultController.Result operation;
            try { operation = vault.authenticate(pass, create, imported); }
            finally { Arrays.fill(pass, '\0'); VaultCrypto.wipe(imported); }
            final VaultData completed = operation.data();
            handler.post(() -> {
                busy = false;
                if (ticket != generation || !foreground || isDestroyed()) {
                    if (completed != null) completed.close();
                    if (!isDestroyed()) showLocked(operation.failure() == VaultController.Failure.NONE
                            ? "Operation finished. Unlock to continue." : authenticationMessage(operation.failure(), create, imported != null));
                    return;
                }
                if (operation.failure() != VaultController.Failure.NONE) {
                    if (completed != null) completed.close();
                    showLocked(authenticationMessage(operation.failure(), create, imported != null));
                } else { vault.activate(completed); showVault(); resetIdle(); }
            });
        });
    }
    private String authenticationMessage(VaultController.Failure failure, boolean create, boolean importing) {
        return switch (failure) {
            case ALREADY_EXISTS -> "A vault already exists. Unlock it instead of creating another one.";
            case LOCAL_STORAGE -> importing
                    ? "The backup password was accepted, but Android could not save the restored vault. Your existing vault was not replaced."
                    : create ? "Android could not create the local vault. Check available storage and try again."
                    : "Android could not save the local vault. Your previous vault is intact.";
            case AUTHENTICATION_OR_DAMAGE -> importing
                    ? "The backup could not be authenticated. The password may be wrong, or the backup may be damaged. Your existing vault was not replaced."
                    : "Could not unlock the vault. Check the master password. If it is correct, the local vault may be damaged or its device key unavailable.";
            case NONE -> "";
        };
    }
    private void showVault() {
        if (vault.session() == null) { showLocked(""); return; }
        newPage("Your vault", "Locks when you leave and after " + autoLockMinutes() + " minute" + (autoLockMinutes() == 1 ? "" : "s") + " without activity.", null, true, true, true);
        button("Add password", () -> edit(null));
        button("Lock vault now", () -> lock(true));
        EditText search = field("Search title, username or website", false, "",
                "Search stays inside this encrypted vault. Password values are never searched.");
        LinearLayout list = new LinearLayout(this); list.setOrientation(LinearLayout.VERTICAL); page.addView(list);
        renderEntries(list, "", ENTRY_PAGE_SIZE);
        final Runnable[] pendingSearch = {null};
        search.addTextChangedListener(new TextWatcher() {
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {}
            public void onTextChanged(CharSequence s, int start, int before, int count) {
                if (pendingSearch[0] != null) handler.removeCallbacks(pendingSearch[0]);
                final int ticket = generation;
                final String query = s.toString();
                pendingSearch[0] = () -> {
                    if (ticket == generation && vault.session() != null)
                        renderEntries(list, query, ENTRY_PAGE_SIZE);
                };
                handler.postDelayed(pendingSearch[0], SEARCH_DELAY_MS);
            }
            public void afterTextChanged(Editable s) {}
        });
        button("Encrypted backups", this::showBackupGuide);
        button("Auto-lock timing", this::showAutoLockTiming);
    }
    private void showAutoLockTiming() {
        newPage("Auto-lock timing", "The vault always locks immediately when you leave the app.", this::showVault);
        text("Choose how long the unlocked vault can stay open without activity while this app remains on screen.");
        text("The vault always locks immediately when you leave the app or lock it yourself.");
        for (int minutes : new int[]{1, 2, 3, 5}) {
            final int choice = minutes;
            String suffix = choice == autoLockMinutes() ? " (current)" : "";
            button(choice + " minute" + (choice == 1 ? "" : "s") + " — " + autoLockTone(choice) + suffix, () -> {
                getSharedPreferences(SETTINGS, MODE_PRIVATE).edit().putInt(AUTO_LOCK_MINUTES, choice).apply();
                resetIdle(); showVault();
            });
        }
    }
    private String autoLockTone(int minutes) {
        return switch (minutes) { case 1 -> "Very strict"; case 2 -> "Balanced";
            case 3 -> "Comfortable"; case 5 -> "Relaxed"; default -> "Very strict"; };
    }
    private void renderEntries(LinearLayout list, String query, int limit) {
        list.removeAllViews(); if (vault.session() == null) return;
        List<VaultData.Entry> matches = VaultEntryList.matching(vault.session().entries, query);
        int shown = Math.min(limit, matches.size());
        for (int i = 0; i < shown; i++) {
            VaultData.Entry entry = matches.get(i);
            button(list, entry.title() + (entry.username().isEmpty() ? "" : "\n" + entry.username()), () -> detail(entry));
        }
        if (matches.isEmpty()) { TextView empty = new TextView(this); empty.setText(query.isEmpty()
                ? "No passwords yet. Tap Add password to get started." : "No matching entries.");
            empty.setPadding(0, dp(16), 0, dp(16)); list.addView(empty); }
        else if (shown < matches.size()) {
            int next = Math.min(shown + ENTRY_PAGE_SIZE, matches.size());
            button(list, "Show more (" + shown + " of " + matches.size() + ")",
                    () -> renderEntries(list, query, next));
        }
    }
    private void detail(VaultData.Entry entry) {
        newPage(entry.title(), ""); text("Username"); text(entry.username());
        button("Copy username", () -> copy(entry.username()));
        text("Password"); TextView hidden = text("••••••••••••"); secretViews.add(hidden);
        Button reveal = button("Reveal for 10 seconds", () -> {});
        reveal.setOnClickListener(v -> {
            if (busy) return;
            resetIdle();
            if (pendingMask != null) {
                handler.removeCallbacks(pendingMask); pendingMask.run(); pendingMask = null;
                return;
            }
            hidden.setText(entry.password()); reveal.setText("Hide password now");
            pendingMask = () -> {
                hidden.setText("••••••••••••"); reveal.setText("Reveal for 10 seconds"); pendingMask = null;
            };
            handler.postDelayed(pendingMask, 10_000);
        });
        button("Copy password", () -> copy(entry.password()));
        if (!entry.website().isEmpty()) { text("Website / app (reference only)"); text(entry.website()); }
        button("Edit", () -> edit(entry));
        button("Delete", () -> {
            dialog = new AlertDialog.Builder(this).setTitle("Delete this entry?")
                    .setMessage("This cannot be undone. Older exported backups will still contain it.")
                    .setNegativeButton("Cancel", null).setPositiveButton("Delete", (d, w) -> {
                        VaultData changed = vault.session().copy(); changed.entries.removeIf(e -> e.id().equals(entry.id())); persist(changed);
                    }).create(); showSecureDialog();
        });
        button("Back to vault", this::showVault); button("Lock vault now", () -> lock(true));
    }
    private void copy(String value) {
        try {
            if (clipboard.copy(value)) message("Copied. Cleanup is scheduled in 20 seconds; Android may delay it while another app is open.");
            else message("Android did not confirm the copy. Clipboard cleanup remains scheduled; tap Copy again while this screen is open.");
        }
        catch (RuntimeException e) { message("Clipboard is unavailable."); }
    }
    private void edit(VaultData.Entry existing) {
        edit(existing, existing);
    }
    private void edit(VaultData.Entry existing, VaultData.Entry draft) {
        newPage(existing == null ? "Add password" : "Edit password", "Leaving the app discards unsaved changes.");
        EditText title = field("Title", false, draft == null ? "" : draft.title(),
                "A label for you, stored encrypted and never sent anywhere.");
        EditText username = field("Username / email", false, draft == null ? "" : draft.username(),
                "Optional. Use whatever helps you recognize the account.");
        EditText secret = field("Password", true, draft == null ? "" : draft.password(),
                "Use Generate password for a local random password, then tap Save to keep it.");
        text("Password generator options");
        Spinner generatedLength = new Spinner(this);
        generatedLength.setContentDescription("Generated password length");
        generatedLength.setSaveEnabled(false);
        ArrayAdapter<String> lengths = new ArrayAdapter<>(this, android.R.layout.simple_spinner_dropdown_item,
                new String[]{"16 characters", "20 characters", "24 characters", "32 characters"});
        generatedLength.setAdapter(lengths); generatedLength.setSelection(1); page.addView(generatedLength);
        CheckBox includeSymbols = new CheckBox(this);
        includeSymbols.setText("Include symbols"); includeSymbols.setChecked(true); includeSymbols.setSaveEnabled(false);
        includeSymbols.setOnCheckedChangeListener((button, checked) -> resetIdle()); page.addView(includeSymbols);
        hint("Turn symbols off only when a website does not accept them. Generated passwords always include uppercase, lowercase, and numbers.");
        button("Generate password", () -> {
            Runnable generate = () -> {
                int length = new int[]{16, 20, 24, 32}[generatedLength.getSelectedItemPosition()];
                secret.setText(PasswordGenerator.generate(length, includeSymbols.isChecked())); resetIdle();
                message("Generated a " + length + "-character password on this device. Tap Save to keep it.");
            };
            if (secret.length() == 0) generate.run();
            else {
                dialog = new AlertDialog.Builder(this).setTitle("Replace the password in this form?")
                        .setMessage("A new random password will fill this field. Your saved entry changes only when you tap Save. This does not change your password on any website.")
                        .setNegativeButton("Cancel", null)
                        .setPositiveButton("Generate", (d, w) -> generate.run()).create();
                showSecureDialog();
            }
        });
        EditText website = field("Website / app (optional)", false, draft == null ? "" : draft.website(),
                "For reference only. This app never opens websites or connects to the internet.");
        button("Save", () -> {
            if (title.getText().toString().trim().isEmpty()) {
                title.setError("Enter a title"); title.requestFocus(); return;
            }
            if (existing == null && vault.session().entries.size() >= VaultData.MAX_ENTRIES) { message("This vault supports up to 2,000 entries."); return; }
            VaultData.Entry entry = new VaultData.Entry(existing == null ? UUID.randomUUID().toString() : existing.id(),
                    title.getText().toString().trim(), username.getText().toString(), secret.getText().toString(), website.getText().toString());
            VaultData changed = vault.session().copy(); changed.entries.removeIf(e -> e.id().equals(entry.id())); changed.entries.add(entry);
            persist(changed, () -> edit(existing, entry));
        });
        button("Cancel", this::showVault);
    }
    private void persist(VaultData changed) {
        persist(changed, this::showVault);
    }
    private void persist(VaultData changed, Runnable restoreOnFailure) {
        final int ticket = generation; busy = true;
        newPage("Saving…", "Encrypting your vault on this device.");
        page.addView(new ProgressBar(this));
        worker.execute(() -> {
            final boolean success = vault.save(changed) == VaultController.Failure.NONE;
            handler.post(() -> {
                busy = false;
                if (ticket != generation || !foreground || isDestroyed()) {
                    changed.close(); if (!isDestroyed()) showLocked(success ? "Saved. Unlock to continue." : "Save failed. Your previous vault is intact."); return;
                }
                if (success) vault.activate(changed);
                else { changed.close(); message("Could not save. The previous vault is intact; please retry the change."); }
                if (success) showVault(); else restoreOnFailure.run();
                resetIdle();
            });
        });
    }
    private void showBackupGuide() {
        newPage("Encrypted backups", "Keep a backup only if you want a second copy of your encrypted vault.", this::showVault);
        text("How backups work");
        text("Your backup is encrypted. It cannot be opened without the master password that protected it. The app never uploads it, but a cloud location chosen in Android's file picker may upload the encrypted file.");

        text("Backup checklist");
        checklist("I saved a fresh .gpv backup file.");
        checklist("I know the master password that protects it.");
        checklist("At least one copy is somewhere other than this device.");
        hint("These checks are only for your own reminder. They are not saved or sent anywhere.");

        text("Export: make a backup");
        text("1. Tap Export encrypted backup below.\n2. Choose local storage, removable storage, or a USB drive in Android's file picker.\n3. Keep the saved .gpv file and your master password in safe places. You need both to restore it.\n4. If you choose a cloud provider, it may upload this encrypted file under its own rules.");
        button("Export encrypted backup", this::prepareExport);

        text("Import: restore a backup");
        text("1. Export this device's current vault first if there is anything you may want to keep.\n2. Tap Import encrypted backup and select a .gpv backup file.\n3. Enter the backup's master password and confirm the replacement.\n4. Import replaces this device's entire vault. It does not merge passwords.");
        button("Import encrypted backup", this::chooseImport);

        text("If you forget the master password, the backup cannot be recovered. Test a new backup before relying on it.");
    }
    private void checklist(String label) {
        CheckBox item = new CheckBox(this); item.setText(label); item.setSaveEnabled(false);
        item.setOnCheckedChangeListener((button, checked) -> resetIdle()); page.addView(item);
    }
    private void showSupport() {
        newPage("Optional support", "This app stays free for everyone.",
                () -> { if (vault.session() == null) showLocked(""); else showVault(); }, false);
        text("Frog Secure PW Keeper is built to be free, simple, and respectful. There are no ads, subscriptions, paid features, or locked tools. Optional support never changes what the app can do.");
        text("The frog-heart button does not connect to the internet. It opens this local page only. The app has no browser link, payment screen, account, or network permission.");
        text("If you ever choose to support the work, you can type this address into your own browser. It is shown here only for your information and is not a link:\nhttps://buymeacoffee.com/frogdadday");
        text("Thank you for using the app. No support is expected or required.");
    }
    private void prepareExport() {
        dialog = new AlertDialog.Builder(this).setTitle("Export encrypted backup")
                .setMessage("This backup uses your current master password. Keep that password to restore it. Choose local storage or a USB drive. "
                        + "Android's file picker may also offer cloud providers: choosing one lets that provider upload the encrypted file.")
                .setNegativeButton("Cancel", null).setPositiveButton("Choose location", (d, w) -> {
                    VaultData snapshot = vault.session().copy(); final int ticket = generation; busy = true;
                    worker.execute(() -> {
                        BackupController.PreparedResult prepared = backups.prepare(snapshot);
                        final byte[] result = prepared.encrypted();
                        handler.post(() -> {
                            busy = false;
                            if (ticket != generation || !foreground || isDestroyed()) { VaultCrypto.wipe(result); if (!isDestroyed()) showLocked(""); return; }
                            if (prepared.failure() != BackupController.Failure.NONE) {
                                message("Could not prepare the encrypted backup. The vault was not changed."); return;
                            }
                            backups.setPendingExport(result);
                            Intent intent = new Intent(Intent.ACTION_CREATE_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE)
                                    .setType("application/octet-stream").putExtra(Intent.EXTRA_TITLE, "frog-secure-pw-keeper.gpv")
                                    .putExtra(Intent.EXTRA_LOCAL_ONLY, true);
                            try { startActivityForResult(intent, EXPORT); }
                            catch (android.content.ActivityNotFoundException e) { backups.clearExport(); message("No file picker is available."); }
                        });
                    });
                }).create(); showSecureDialog();
    }
    private void chooseImport() {
        dialog = new AlertDialog.Builder(this).setTitle("Import encrypted backup")
                .setMessage("Import replaces this device's vault; it does not merge entries. Export your current vault first if you want to keep it. "
                        + "You will need the backup's master password. A wrong password or damaged file will not replace the current vault.")
                .setNegativeButton("Cancel", null).setPositiveButton("Choose backup", (d, w) -> {
                    Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE)
                            .setType("*/*").putExtra(Intent.EXTRA_LOCAL_ONLY, true);
                    try { startActivityForResult(intent, IMPORT); }
                    catch (android.content.ActivityNotFoundException e) { message("No file picker is available."); }
                }).create(); showSecureDialog();
    }
    @Override protected void onActivityResult(int request, int result, Intent data) {
        super.onActivityResult(request, result, data);
        if (result != RESULT_OK || data == null || data.getData() == null) {
            if (request == EXPORT) backups.clearExport(); return;
        }
        Uri uri = data.getData();
        if (request == EXPORT && !backups.hasPendingExport()) {
            showLocked(EXPORT_INTERRUPTED);
            return;
        }
        if (request == EXPORT) {
            final byte[] encrypted = backups.takePendingExport(); busy = true;
            worker.execute(() -> {
                BackupController.Failure failure = backups.write(getContentResolver(), uri, encrypted);
                handler.post(() -> { busy = false; if (!isDestroyed()) showLocked(failure == BackupController.Failure.NONE
                        ? "Encrypted backup exported. Keep it and your master password safe."
                        : "Android could not finish writing the backup. The destination may be incomplete; delete it and export again."); });
            });
        } else if (request == IMPORT) {
            busy = true; final int ticket = generation;
            worker.execute(() -> {
                BackupController.ReadResult read = backups.read(getContentResolver(), uri);
                final byte[] encrypted = read.encrypted();
                handler.post(() -> {
                    busy = false;
                    if (ticket != generation || isDestroyed()) { VaultCrypto.wipe(encrypted); return; }
                    if (read.failure() != BackupController.Failure.NONE) {
                        showLocked(backupReadMessage(read.failure())); return;
                    }
                    backups.setPendingImport(encrypted); showImport();
                });
            });
        }
    }
    private String backupReadMessage(BackupController.Failure failure) {
        return switch (failure) {
            case TOO_LARGE -> "This file is too large to be a Frog Secure PW Keeper backup.";
            case UNSUPPORTED_VERSION -> "This backup version is not supported by this app version. Update the app that will restore it, or choose a compatible backup.";
            case DAMAGED_OR_UNREADABLE -> "Android could not read this as a complete Frog Secure PW Keeper backup. The file may be damaged or access may have been interrupted.";
            case STORAGE -> "Android could not access the selected storage location. Choose the file again or try another location.";
            case NONE -> "";
        };
    }
    private void showImport() {
        newPage("Restore backup", "Use the master password that protected this backup when it was exported.");
        EditText master = field("Backup master password", true, "");
        text("Restoring replaces all current entries. It becomes your vault, using the backup's master password.");
        CheckBox confirm = new CheckBox(this); confirm.setText(R.string.confirm_replace); page.addView(confirm);
        button("Restore and replace vault", () -> {
            if (!confirm.isChecked()) { message("Confirm replacement before restoring."); return; }
            byte[] blob = backups.takePendingImport();
            if (blob != null) authenticate(password(master), false, blob);
        });
        button("Cancel", () -> { backups.clearImport(); showLocked(""); });
    }
    private void showHelp() {
        newPage("Privacy & help", "No catch. Just a free app made to be useful.",
                () -> { if (vault.session() == null) showLocked(""); else showVault(); });
        text("How it works");
        text("1. Your master password unlocks an encrypted vault stored on this device. It is never stored by the app.\n"
                + "2. The vault locks when you leave the app or after the selected idle time.\n"
                + "3. Export creates an encrypted .gpv backup only when you choose it. Restoring one replaces this device's vault.");
        text("Privacy policy\nEffective date: October 10, 2026");
        text("Frog Secure PW Keeper is an offline password safe. It does not collect, transmit, sell, or share personal information. "
                + "There are no ads, analytics, accounts, subscriptions, cloud service, tracking tools, or internet permission.");
        text("Your passwords, usernames, websites, and titles stay in the app's private storage on this device. The vault is encrypted, "
                + "and your master password is never stored. Android's hardware-backed Keystore is used when available.");
        text("Automatic Android backup is disabled. Manual export creates an encrypted backup only when you ask it to. If you select a cloud "
                + "provider in Android's file picker, that provider may upload the encrypted file under its own privacy policy.");
        text("Copied usernames and passwords are marked sensitive and scheduled to clear after 20 seconds. Android can delay that cleanup while "
                + "another app is open, and keyboards or clipboard-history apps may keep their own copy.");
        text("Help\nThere is no password reset. If you forget the master password, the vault and encrypted backups cannot be recovered. "
                + "Export an encrypted backup before changing phones, resetting a device, or relying on the vault for important passwords.");
        text("The vault locks when you leave the app and after the selected 1–5 minute inactivity period. Screenshots and screen recording are blocked where Android supports it.");
        text("Contact\nOpen an issue in the public privacy-policy repository or email thefirstfrogdadday@gmail.com.");
        text("Privacy policy address, shown for reference only (this app does not open it):\nhttps://frogdadday.github.io/frog-secure-pw-keeper-privacy/");
        text("Version 0.1.1. Keep an encrypted backup and remember your master password; there is no password reset.");
    }
}

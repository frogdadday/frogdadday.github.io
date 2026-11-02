package app.grounded.password;

import android.content.ContentResolver;
import android.net.Uri;
import java.io.FileNotFoundException;
import java.io.InputStream;

/** Owns encrypted import/export state and provider I/O. Never stores plaintext or a password. */
final class BackupController {
    enum Failure { NONE, TOO_LARGE, UNSUPPORTED_VERSION, DAMAGED_OR_UNREADABLE, STORAGE }
    record ReadResult(byte[] encrypted, Failure failure) {}
    record PreparedResult(byte[] encrypted, Failure failure) {}
    static final class RetainedExport {
        final byte[] encrypted;
        RetainedExport(byte[] encrypted) { this.encrypted = encrypted; }
    }

    private byte[] pendingExport;
    private byte[] pendingImport;

    void restoreRetained(Object retained) {
        if (retained instanceof RetainedExport export) pendingExport = export.encrypted;
    }
    RetainedExport retainedExport() { return pendingExport == null ? null : new RetainedExport(pendingExport); }
    boolean hasPendingExport() { return pendingExport != null; }
    void setPendingExport(byte[] encrypted) { clearExport(); pendingExport = encrypted; }
    byte[] takePendingExport() { byte[] result = pendingExport; pendingExport = null; return result; }
    void clearExport() { VaultCrypto.wipe(pendingExport); pendingExport = null; }
    void setPendingImport(byte[] encrypted) { clearImport(); pendingImport = encrypted; }
    byte[] takePendingImport() { byte[] result = pendingImport; pendingImport = null; return result; }
    void clearImport() { VaultCrypto.wipe(pendingImport); pendingImport = null; }
    void clearAll(boolean keepExport) { if (!keepExport) clearExport(); clearImport(); }

    PreparedResult prepare(VaultData snapshot) {
        try { return new PreparedResult(snapshot.encrypted(), Failure.NONE); }
        catch (Exception ignored) { return new PreparedResult(null, Failure.STORAGE); }
        finally { snapshot.close(); }
    }

    Failure write(ContentResolver resolver, Uri uri, byte[] encrypted) {
        try {
            BackupExport.write(resolver.openOutputStream(uri, "wt"), encrypted);
            return Failure.NONE;
        } catch (Exception ignored) {
            return Failure.STORAGE;
        } finally { VaultCrypto.wipe(encrypted); }
    }

    ReadResult read(ContentResolver resolver, Uri uri) {
        byte[] blob = null;
        try (InputStream in = resolver.openInputStream(uri)) {
            blob = VaultStore.readBounded(in, VaultCrypto.MAX_FILE_BYTES);
            byte[] salt = VaultCrypto.readSalt(blob);
            VaultCrypto.wipe(salt);
            return new ReadResult(blob, Failure.NONE);
        } catch (VaultStore.FileTooLargeException ignored) {
            VaultCrypto.wipe(blob); return new ReadResult(null, Failure.TOO_LARGE);
        } catch (BackupFormatException e) {
            VaultCrypto.wipe(blob);
            return new ReadResult(null, e.reason == BackupFormatException.Reason.UNSUPPORTED
                    ? Failure.UNSUPPORTED_VERSION : Failure.DAMAGED_OR_UNREADABLE);
        } catch (FileNotFoundException | SecurityException ignored) {
            VaultCrypto.wipe(blob); return new ReadResult(null, Failure.STORAGE);
        } catch (Exception ignored) {
            VaultCrypto.wipe(blob); return new ReadResult(null, Failure.DAMAGED_OR_UNREADABLE);
        }
    }
}

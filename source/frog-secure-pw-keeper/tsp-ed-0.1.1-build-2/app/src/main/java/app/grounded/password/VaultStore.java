package app.grounded.password;

import android.content.Context;
import android.content.pm.PackageManager;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.security.keystore.StrongBoxUnavailableException;
import android.util.AtomicFile;
import java.io.*;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.security.KeyStore;
import java.security.GeneralSecurityException;
import java.util.Arrays;
import javax.crypto.*;
import javax.crypto.spec.GCMParameterSpec;

/** Device-bound outer encryption. Portable exports contain only password encryption. */
final class VaultStore {
    static final class FileTooLargeException extends IOException {
        FileTooLargeException() { super("File too large"); }
    }
    private static final String ALIAS = "grounded.vault.device.v1";
    private static final byte[] MAGIC = "GRNDDEV1".getBytes(StandardCharsets.US_ASCII);
    private final Context context;
    private final AtomicFile file;
    VaultStore(Context context) {
        this.context = context.getApplicationContext();
        file = new AtomicFile(new File(context.getNoBackupFilesDir(), "vault.bin"));
    }
    boolean exists() { return file.getBaseFile().exists() || new File(file.getBaseFile() + ".bak").exists(); }

    private SecretKey deviceKey(boolean create) throws Exception {
        KeyStore ks = KeyStore.getInstance("AndroidKeyStore"); ks.load(null);
        if (ks.containsAlias(ALIAS)) return (SecretKey) ks.getKey(ALIAS, null);
        if (!create || exists()) throw new GeneralSecurityException("Device key unavailable");
        if (context.getPackageManager().hasSystemFeature(PackageManager.FEATURE_STRONGBOX_KEYSTORE)) {
            try { return generate(true); }
            catch (StrongBoxUnavailableException ignored) { /* Standard Keystore fallback. */ }
        }
        return generate(false);
    }
    private SecretKey generate(boolean strongBox) throws Exception {
        KeyGenerator generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore");
        generator.init(new KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT)
                .setKeySize(256).setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setRandomizedEncryptionRequired(true).setIsStrongBoxBacked(strongBox).build());
        return generator.generateKey();
    }
    byte[] read() throws Exception {
        byte[] wrapped;
        try (InputStream in = file.openRead()) { wrapped = readBounded(in, VaultCrypto.MAX_FILE_BYTES + 36); }
        if (wrapped.length < 36 || !Arrays.equals(MAGIC, Arrays.copyOf(wrapped, 8)))
            throw new IOException("Invalid device vault");
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(Cipher.DECRYPT_MODE, deviceKey(false), new GCMParameterSpec(128, Arrays.copyOfRange(wrapped, 8, 20)));
        cipher.updateAAD(MAGIC);
        return cipher.doFinal(wrapped, 20, wrapped.length - 20);
    }
    void write(byte[] encrypted) throws Exception {
        if (encrypted.length > VaultCrypto.MAX_FILE_BYTES) throw new IOException("Vault too large");
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(Cipher.ENCRYPT_MODE, deviceKey(true));
        cipher.updateAAD(MAGIC);
        byte[] ciphertext = cipher.doFinal(encrypted);
        byte[] wrapped = ByteBuffer.allocate(20 + ciphertext.length).put(MAGIC).put(cipher.getIV()).put(ciphertext).array();
        FileOutputStream out = null;
        try { out = file.startWrite(); out.write(wrapped); file.finishWrite(out); }
        catch (Exception e) { if (out != null) file.failWrite(out); throw e; }
    }
    static byte[] readBounded(InputStream in, int limit) throws IOException {
        if (in == null) throw new IOException("Cannot open file");
        ByteArrayOutputStream out = new ByteArrayOutputStream(); byte[] buffer = new byte[8192];
        int size;
        while ((size = in.read(buffer)) != -1) {
            // A few third-party document providers have returned zero-length reads. Avoid a busy loop.
            if (size == 0) {
                int one = in.read();
                if (one == -1) break;
                if (out.size() >= limit) throw new FileTooLargeException();
                out.write(one);
                continue;
            }
            if (out.size() + size > limit) throw new FileTooLargeException();
            out.write(buffer, 0, size);
        }
        return out.toByteArray();
    }
}

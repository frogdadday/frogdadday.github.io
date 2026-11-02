package app.grounded.password;

import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.SecureRandom;
import java.util.Arrays;
import javax.crypto.Cipher;
import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.PBEKeySpec;
import javax.crypto.spec.SecretKeySpec;

/** Versioned serialization around JCA primitives, not a cryptographic algorithm. */
public final class VaultCrypto {
    public static final int MAX_FILE_BYTES = 2 * 1024 * 1024;
    public static final int ITERATIONS = 600_000;
    private static final byte[] MAGIC_V1 = "GRNDPW01".getBytes(StandardCharsets.US_ASCII);
    private static final byte[] MAGIC_V2 = "GRNDPW02".getBytes(StandardCharsets.US_ASCII);
    private static final int V1_HEADER = 8 + 4 + 16 + 12;
    private static final int V2_HEADER = 8 + 4 + 4 + 16 + 12;
    private static final int CURRENT_FORMAT = 2;
    private static final SecureRandom RANDOM = new SecureRandom();

    public static byte[] salt() { byte[] b = new byte[16]; RANDOM.nextBytes(b); return b; }

    public static byte[] derive(char[] password, byte[] salt) throws GeneralSecurityException {
        return derive(password, salt, ITERATIONS);
    }

    private static byte[] derive(char[] password, byte[] salt, int iterations) throws GeneralSecurityException {
        if (salt.length != 16) throw new GeneralSecurityException("Invalid salt");
        if (iterations != ITERATIONS) throw new GeneralSecurityException("Unsupported password protection");
        PBEKeySpec spec = new PBEKeySpec(password, salt, iterations, 256);
        try { return SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec).getEncoded(); }
        finally { spec.clearPassword(); }
    }

    public static byte[] seal(byte[] plaintext, byte[] key, byte[] salt) throws GeneralSecurityException {
        if (plaintext.length > MAX_FILE_BYTES - V2_HEADER - 16 || key.length != 32 || salt.length != 16)
            throw new GeneralSecurityException("Vault too large or invalid key");
        byte[] nonce = new byte[12]; RANDOM.nextBytes(nonce);
        byte[] header = ByteBuffer.allocate(V2_HEADER).put(MAGIC_V2).putInt(CURRENT_FORMAT)
                .putInt(ITERATIONS).put(salt).put(nonce).array();
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(Cipher.ENCRYPT_MODE, new SecretKeySpec(key, "AES"), new GCMParameterSpec(128, nonce));
        cipher.updateAAD(header);
        byte[] encrypted = cipher.doFinal(plaintext);
        return ByteBuffer.allocate(header.length + encrypted.length).put(header).put(encrypted).array();
    }

    public static byte[] readSalt(byte[] file) throws GeneralSecurityException {
        return parameters(file).salt;
    }

    /** Reads a deliberately small allow-list of format and KDF parameters before deriving a key. */
    private static Parameters parameters(byte[] file) throws GeneralSecurityException {
        if (file.length > MAX_FILE_BYTES || file.length < V1_HEADER + 16)
            throw new BackupFormatException(BackupFormatException.Reason.DAMAGED);
        ByteBuffer header = ByteBuffer.wrap(file);
        byte[] magic = new byte[8]; header.get(magic);
        if (Arrays.equals(MAGIC_V1, magic)) {
            int iterations = header.getInt();
            if (iterations != ITERATIONS) throw new BackupFormatException(BackupFormatException.Reason.UNSUPPORTED);
            byte[] salt = new byte[16]; header.get(salt);
            return new Parameters(salt, iterations, V1_HEADER);
        }
        if (Arrays.equals(MAGIC_V2, magic)) {
            if (file.length < V2_HEADER + 16)
                throw new BackupFormatException(BackupFormatException.Reason.DAMAGED);
            if (header.getInt() != CURRENT_FORMAT)
                throw new BackupFormatException(BackupFormatException.Reason.UNSUPPORTED);
            int iterations = header.getInt();
            if (iterations != ITERATIONS) throw new BackupFormatException(BackupFormatException.Reason.UNSUPPORTED);
            byte[] salt = new byte[16]; header.get(salt);
            return new Parameters(salt, iterations, V2_HEADER);
        }
        throw new BackupFormatException(BackupFormatException.Reason.UNSUPPORTED);
    }

    public static byte[] open(byte[] file, byte[] key) throws GeneralSecurityException {
        Parameters params = parameters(file);
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(Cipher.DECRYPT_MODE, new SecretKeySpec(key, "AES"),
                new GCMParameterSpec(128, Arrays.copyOfRange(file, params.headerLength - 12, params.headerLength)));
        cipher.updateAAD(file, 0, params.headerLength);
        return cipher.doFinal(file, params.headerLength, file.length - params.headerLength);
    }

    public static void wipe(byte[] bytes) { if (bytes != null) Arrays.fill(bytes, (byte) 0); }
    private record Parameters(byte[] salt, int iterations, int headerLength) {}
    private VaultCrypto() {}
}

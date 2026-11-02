package app.grounded.password;

import org.junit.Test;
import static org.junit.Assert.*;
import java.util.*;
import java.io.*;
import java.security.GeneralSecurityException;

public class VaultTest {
    @Test public void largeEntryCatalogueFiltersAndSortsWithoutDroppingResults() {
        List<VaultData.Entry> entries = new ArrayList<>();
        for (int i = 1999; i >= 0; i--) {
            entries.add(new VaultData.Entry(UUID.randomUUID().toString(),
                    String.format(Locale.ROOT, "Account %04d", i), "user" + i, "secret", "example.test"));
        }
        List<VaultData.Entry> all = VaultEntryList.matching(entries, "");
        assertEquals(2000, all.size());
        assertEquals("Account 0000", all.get(0).title());
        assertEquals("Account 1999", all.get(1999).title());
        assertEquals(1, VaultEntryList.matching(entries, "user1379").size());
    }

    private VaultData.Entry entry() {
        return new VaultData.Entry(UUID.randomUUID().toString(), "Example", "user@example.test", "secret-🔐-é", "example.test");
    }
    @Test public void passwordRoundTripAndWrongPassword() throws Exception {
        byte[] salt = VaultCrypto.salt(); byte[] key = VaultCrypto.derive("correct horse battery".toCharArray(), salt);
        try (VaultData original = new VaultData(key, salt, List.of(entry()))) {
            byte[] encrypted = original.encrypted();
            try (VaultData restored = VaultData.unlock(encrypted, "correct horse battery".toCharArray())) {
                assertEquals(original.entries, restored.entries);
            }
            assertThrows(GeneralSecurityException.class, () -> VaultData.unlock(encrypted, "wrong".toCharArray()));
            assertFalse(new String(encrypted, java.nio.charset.StandardCharsets.ISO_8859_1).contains("user@example.test"));
        } finally { VaultCrypto.wipe(key); }
    }
    @Test public void eachByteIsAuthenticatedOrRejected() throws Exception {
        byte[] key = new byte[32], salt = VaultCrypto.salt();
        byte[] encrypted = VaultCrypto.seal("secret".getBytes(), key, salt);
        for (int index = 0; index < encrypted.length; index++) {
            byte[] tampered = encrypted.clone(); tampered[index] ^= 1;
            assertThrows(GeneralSecurityException.class, () -> VaultCrypto.open(tampered, key));
        }
    }
    @Test public void freshNonceForEverySave() throws Exception {
        byte[] key = new byte[32], salt = VaultCrypto.salt(), plaintext = new byte[128];
        assertFalse(Arrays.equals(VaultCrypto.seal(plaintext, key, salt), VaultCrypto.seal(plaintext, key, salt)));
    }
    @Test public void truncationAndTrailingBytesRejected() throws Exception {
        byte[] key = new byte[32]; byte[] blob = VaultCrypto.seal(new byte[10], key, VaultCrypto.salt());
        for (int n = 0; n < blob.length; n++) {
            byte[] truncated = Arrays.copyOf(blob, n);
            assertThrows(GeneralSecurityException.class, () -> VaultCrypto.open(truncated, key));
        }
        assertThrows(GeneralSecurityException.class, () -> VaultCrypto.open(Arrays.copyOf(blob, blob.length + 1), key));
    }
    @Test public void oversizedFilesRejectedBeforeKdf() {
        BackupFormatException error = assertThrows(BackupFormatException.class,
                () -> VaultCrypto.readSalt(new byte[VaultCrypto.MAX_FILE_BYTES + 1]));
        assertEquals(BackupFormatException.Reason.DAMAGED, error.reason);
    }
    @Test public void kdfParametersCannotRequestUnboundedWork() throws Exception {
        byte[] blob = VaultCrypto.seal(new byte[1], new byte[32], VaultCrypto.salt());
        java.nio.ByteBuffer.wrap(blob, 12, 4).putInt(Integer.MAX_VALUE);
        BackupFormatException error = assertThrows(BackupFormatException.class, () -> VaultCrypto.readSalt(blob));
        assertEquals(BackupFormatException.Reason.UNSUPPORTED, error.reason);
    }
    @Test public void truncatedCurrentHeaderIsClassifiedAsDamaged() throws Exception {
        byte[] blob = VaultCrypto.seal(new byte[1], new byte[32], VaultCrypto.salt());
        BackupFormatException error = assertThrows(BackupFormatException.class,
                () -> VaultCrypto.readSalt(Arrays.copyOf(blob, 58)));
        assertEquals(BackupFormatException.Reason.DAMAGED, error.reason);
    }
    @Test public void currentFilesUseAnExplicitVersionAndWorkFactor() throws Exception {
        byte[] blob = VaultCrypto.seal(new byte[1], new byte[32], VaultCrypto.salt());
        assertArrayEquals("GRNDPW02".getBytes(java.nio.charset.StandardCharsets.US_ASCII), Arrays.copyOf(blob, 8));
        assertEquals(2, java.nio.ByteBuffer.wrap(blob, 8, 4).getInt());
        assertEquals(VaultCrypto.ITERATIONS, java.nio.ByteBuffer.wrap(blob, 12, 4).getInt());
    }
    @Test public void legacyV1BackupsRemainReadable() throws Exception {
        byte[] salt = VaultCrypto.salt(); byte[] key = VaultCrypto.derive("legacy passphrase".toCharArray(), salt);
        VaultData.Entry entry = entry(); byte[] plaintext = VaultData.encode(List.of(entry));
        byte[] nonce = new byte[12]; new java.security.SecureRandom().nextBytes(nonce);
        byte[] header = java.nio.ByteBuffer.allocate(40).put("GRNDPW01".getBytes(java.nio.charset.StandardCharsets.US_ASCII))
                .putInt(VaultCrypto.ITERATIONS).put(salt).put(nonce).array();
        javax.crypto.Cipher cipher = javax.crypto.Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(javax.crypto.Cipher.ENCRYPT_MODE, new javax.crypto.spec.SecretKeySpec(key, "AES"),
                new javax.crypto.spec.GCMParameterSpec(128, nonce));
        cipher.updateAAD(header); byte[] encrypted = cipher.doFinal(plaintext);
        byte[] legacy = java.nio.ByteBuffer.allocate(header.length + encrypted.length).put(header).put(encrypted).array();
        try (VaultData restored = VaultData.unlock(legacy, "legacy passphrase".toCharArray())) {
            assertEquals(List.of(entry), restored.entries);
        } finally { VaultCrypto.wipe(key); VaultCrypto.wipe(plaintext); }
    }
    @Test public void emptyAndUnicodePayloadRoundTrip() throws Exception {
        assertEquals(List.of(), VaultData.decode(VaultData.encode(List.of())));
        List<VaultData.Entry> list = List.of(entry()); assertEquals(list, VaultData.decode(VaultData.encode(list)));
    }
    @Test public void duplicateIdsAndInvalidCountsRejected() throws Exception {
        VaultData.Entry e = entry();
        assertThrows(IOException.class, () -> VaultData.decode(VaultData.encode(List.of(e, e))));
        byte[] payload = java.nio.ByteBuffer.allocate(8).putInt(1).putInt(Integer.MAX_VALUE).array();
        assertThrows(IOException.class, () -> VaultData.decode(payload));
    }
    @Test public void payloadTrailingDataRejected() throws Exception {
        byte[] payload = VaultData.encode(List.of(entry()));
        assertThrows(IOException.class, () -> VaultData.decode(Arrays.copyOf(payload, payload.length + 1)));
    }
    @Test public void searchDoesNotInspectPasswords() {
        VaultData.Entry e = entry(); assertTrue(e.matches("EXAMPLE")); assertFalse(e.matches("secret-"));
    }
    @Test public void closingSessionWipesOwnedKeysAndEntries() {
        byte[] key = new byte[32]; Arrays.fill(key, (byte) 5);
        VaultData data = new VaultData(key, VaultCrypto.salt(), List.of(entry())); data.close();
        assertArrayEquals(new byte[32], data.key); assertTrue(data.entries.isEmpty());
        assertEquals(5, key[0]); // Session owns a copy, never somebody else's array.
    }
    @Test public void invalidFieldsRejected() {
        assertThrows(IllegalArgumentException.class, () -> new VaultData.Entry("bad id", "Title", "", "", ""));
        assertThrows(IllegalArgumentException.class, () -> new VaultData.Entry(UUID.randomUUID().toString(), " ", "", "", ""));
        assertThrows(IllegalArgumentException.class, () -> new VaultData.Entry(UUID.randomUUID().toString(), "Title", "", "x".repeat(4097), ""));
    }
    @Test public void boundedReaderHandlesNonstandardZeroLengthProviderReads() throws Exception {
        InputStream provider = new InputStream() {
            private final byte[] bytes = {7, 8, 9}; private int index; private boolean returnedZero;
            @Override public int read(byte[] buffer, int offset, int length) {
                if (!returnedZero) { returnedZero = true; return 0; }
                if (index >= bytes.length) return -1;
                int count = Math.min(length, bytes.length - index);
                System.arraycopy(bytes, index, buffer, offset, count); index += count; return count;
            }
            @Override public int read() { return index < bytes.length ? bytes[index++] : -1; }
        };
        assertArrayEquals(new byte[]{7, 8, 9}, VaultStore.readBounded(provider, 3));
    }
}

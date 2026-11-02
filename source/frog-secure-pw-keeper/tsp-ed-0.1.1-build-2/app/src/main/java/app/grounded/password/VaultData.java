package app.grounded.password;

import java.io.*;
import java.util.*;

/** Entire payload, including entry titles, is encrypted. No plaintext database/index. */
public final class VaultData implements AutoCloseable {
    public static final int MAX_ENTRIES = 2000;
    public final List<Entry> entries;
    final byte[] key;
    final byte[] salt;

    public record Entry(String id, String title, String username, String password, String website) {
        public Entry {
            UUID.fromString(id);
            if (title.trim().isEmpty()) throw new IllegalArgumentException("Title is required");
            for (String value : new String[]{title, username, password, website})
                if (value.length() > 4096) throw new IllegalArgumentException("Field too long");
        }
        public boolean matches(String query) {
            String q = query.toLowerCase(Locale.ROOT);
            return title.toLowerCase(Locale.ROOT).contains(q)
                    || username.toLowerCase(Locale.ROOT).contains(q)
                    || website.toLowerCase(Locale.ROOT).contains(q);
        }
    }

    public VaultData(byte[] key, byte[] salt, List<Entry> entries) {
        this.key = key.clone(); this.salt = salt.clone(); this.entries = new ArrayList<>(entries);
    }
    public VaultData copy() { return new VaultData(key, salt, entries); }

    public byte[] encrypted() throws Exception {
        byte[] plaintext = encode(entries);
        try { return VaultCrypto.seal(plaintext, key, salt); }
        finally { VaultCrypto.wipe(plaintext); }
    }

    public static VaultData unlock(byte[] encrypted, char[] password) throws Exception {
        byte[] salt = VaultCrypto.readSalt(encrypted);
        byte[] key = VaultCrypto.derive(password, salt);
        byte[] plain = null;
        try { plain = VaultCrypto.open(encrypted, key); return new VaultData(key, salt, decode(plain)); }
        finally { VaultCrypto.wipe(key); VaultCrypto.wipe(plain); }
    }

    static byte[] encode(List<Entry> entries) throws IOException {
        if (entries.size() > MAX_ENTRIES) throw new IOException("Entry limit reached");
        WipingBuffer bytes = new WipingBuffer();
        try (DataOutputStream out = new DataOutputStream(bytes)) {
            out.writeInt(1); out.writeInt(entries.size());
            for (Entry e : entries) {
                out.writeUTF(e.id()); out.writeUTF(e.title()); out.writeUTF(e.username());
                out.writeUTF(e.password()); out.writeUTF(e.website());
                if (bytes.size() > VaultCrypto.MAX_FILE_BYTES - 60) throw new IOException("Vault too large");
            }
            // Current portable framing is a 44-byte header plus a 16-byte GCM tag.
            if (bytes.size() > VaultCrypto.MAX_FILE_BYTES - 60) throw new IOException("Vault too large");
            return bytes.toByteArray();
        } finally { bytes.wipe(); }
    }

    private static final class WipingBuffer extends ByteArrayOutputStream {
        void wipe() { Arrays.fill(buf, (byte) 0); reset(); }
    }

    static List<Entry> decode(byte[] bytes) throws IOException {
        if (bytes.length > VaultCrypto.MAX_FILE_BYTES) throw new IOException("Vault too large");
        try (DataInputStream in = new DataInputStream(new ByteArrayInputStream(bytes))) {
            if (in.readInt() != 1) throw new IOException("Unsupported payload");
            int count = in.readInt();
            if (count < 0 || count > MAX_ENTRIES) throw new IOException("Invalid entry count");
            List<Entry> result = new ArrayList<>(); Set<String> ids = new HashSet<>();
            for (int i = 0; i < count; i++) {
                Entry e = new Entry(in.readUTF(), in.readUTF(), in.readUTF(), in.readUTF(), in.readUTF());
                if (!ids.add(e.id())) throw new IOException("Duplicate entry");
                result.add(e);
            }
            if (in.available() != 0) throw new IOException("Unexpected trailing data");
            return result;
        } catch (IllegalArgumentException e) { throw new IOException("Invalid entry", e); }
    }
    @Override public void close() { VaultCrypto.wipe(key); VaultCrypto.wipe(salt); entries.clear(); }
}

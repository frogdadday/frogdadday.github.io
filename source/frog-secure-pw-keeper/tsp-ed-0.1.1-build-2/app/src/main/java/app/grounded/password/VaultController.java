package app.grounded.password;

import android.content.Context;
import java.util.Collections;

/** Owns the unlocked session and all local-vault cryptographic orchestration. */
final class VaultController {
    enum Failure { NONE, ALREADY_EXISTS, AUTHENTICATION_OR_DAMAGE, LOCAL_STORAGE }
    record Result(VaultData data, Failure failure) {}
    private final VaultStore store;
    private VaultData session;

    VaultController(Context context) { store = new VaultStore(context); }
    boolean exists() { return store.exists(); }
    VaultData session() { return session; }
    void activate(VaultData replacement) {
        if (session != null) session.close();
        session = replacement;
    }
    void lock() { if (session != null) { session.close(); session = null; } }

    Result authenticate(char[] pass, boolean create, byte[] imported) {
        VaultData result = null;
        if (create) {
            try {
                if (store.exists()) return new Result(null, Failure.ALREADY_EXISTS);
                byte[] salt = VaultCrypto.salt(); byte[] key = VaultCrypto.derive(pass, salt);
                try { result = new VaultData(key, salt, Collections.emptyList()); }
                finally { VaultCrypto.wipe(key); VaultCrypto.wipe(salt); }
                store.write(result.encrypted());
                return new Result(result, Failure.NONE);
            } catch (Exception ignored) {
                if (result != null) result.close();
                return new Result(null, Failure.LOCAL_STORAGE);
            }
        }
        if (imported != null) {
            try { result = VaultData.unlock(imported, pass); }
            catch (Exception ignored) { return new Result(null, Failure.AUTHENTICATION_OR_DAMAGE); }
            try { store.write(result.encrypted()); return new Result(result, Failure.NONE); }
            catch (Exception ignored) { result.close(); return new Result(null, Failure.LOCAL_STORAGE); }
        }
        byte[] blob = null;
        try { blob = store.read(); result = VaultData.unlock(blob, pass); return new Result(result, Failure.NONE); }
        catch (Exception ignored) { if (result != null) result.close(); return new Result(null, Failure.AUTHENTICATION_OR_DAMAGE); }
        finally { VaultCrypto.wipe(blob); }
    }

    Failure save(VaultData changed) {
        try { store.write(changed.encrypted()); return Failure.NONE; }
        catch (Exception ignored) { return Failure.LOCAL_STORAGE; }
    }
}

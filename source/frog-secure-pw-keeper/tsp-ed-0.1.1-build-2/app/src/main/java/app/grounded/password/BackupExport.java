package app.grounded.password;

import java.io.IOException;
import java.io.OutputStream;

/** Owns the provider stream; completion includes flush AND close. */
final class BackupExport {
    static void write(OutputStream stream, byte[] encrypted) throws IOException {
        if (stream == null) throw new IOException("Destination unavailable");
        try (OutputStream out = stream) {
            out.write(encrypted);
            out.flush();
        }
    }
    private BackupExport() {}
}

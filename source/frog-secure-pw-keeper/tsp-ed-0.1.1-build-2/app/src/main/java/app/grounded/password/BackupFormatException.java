package app.grounded.password;

import java.security.GeneralSecurityException;

/** Safe, non-secret classification for portable backup framing failures. */
final class BackupFormatException extends GeneralSecurityException {
    enum Reason { UNSUPPORTED, DAMAGED }
    final Reason reason;
    BackupFormatException(Reason reason) {
        super(reason == Reason.UNSUPPORTED ? "Unsupported backup format" : "Damaged backup framing");
        this.reason = reason;
    }
}

package app.grounded.password;

import java.security.SecureRandom;
import java.util.Arrays;

/** Local generation using the platform CSPRNG and unbiased bounded selection. */
final class PasswordGenerator {
    private static final SecureRandom RANDOM = new SecureRandom();
    private static final String UPPER = "ABCDEFGHJKLMNPQRSTUVWXYZ";
    private static final String LOWER = "abcdefghijkmnopqrstuvwxyz";
    private static final String DIGITS = "23456789";
    private static final String SYMBOLS = "!@#$%&*?-_";
    private static final String ALPHABET = UPPER + LOWER + DIGITS + SYMBOLS;

    static String generate() { return generate(20, true); }

    static String generate(int length, boolean includeSymbols) {
        if (length != 16 && length != 20 && length != 24 && length != 32)
            throw new IllegalArgumentException("Unsupported password length");
        String alphabet = includeSymbols ? ALPHABET : UPPER + LOWER + DIGITS;
        char[] password = new char[length];
        try {
            // Rejection sampling keeps all accepted strings equally likely.
            do {
                for (int i = 0; i < password.length; i++)
                    password[i] = alphabet.charAt(RANDOM.nextInt(alphabet.length()));
            } while (!contains(password, UPPER) || !contains(password, LOWER)
                    || !contains(password, DIGITS) || (includeSymbols && !contains(password, SYMBOLS)));
            return new String(password);
        } finally { Arrays.fill(password, '\0'); }
    }
    private static boolean contains(char[] password, String group) {
        for (char c : password) if (group.indexOf(c) >= 0) return true;
        return false;
    }
    private PasswordGenerator() {}
}

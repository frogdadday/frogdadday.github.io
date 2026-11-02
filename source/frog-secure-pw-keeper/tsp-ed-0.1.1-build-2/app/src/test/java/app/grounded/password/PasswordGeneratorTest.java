package app.grounded.password;

import org.junit.Test;
import static org.junit.Assert.*;

public class PasswordGeneratorTest {
    @Test public void generatedPasswordsMeetTheDisplayedPolicy() {
        for (int i = 0; i < 100; i++) {
            String value = PasswordGenerator.generate();
            assertEquals(20, value.length());
            assertTrue(value.matches(".*[A-Z].*"));
            assertTrue(value.matches(".*[a-z].*"));
            assertTrue(value.matches(".*[2-9].*"));
            assertTrue(value.matches(".*[!@#$%&*?_-].*"));
            assertFalse(value.contains(" "));
        }
        // This tests policy only; it is not a statistical certification of SecureRandom.
    }

    @Test public void supportedLengthsAndNoSymbolsModeMeetPolicy() {
        for (int length : new int[]{16, 20, 24, 32}) for (int i = 0; i < 50; i++) {
            String value = PasswordGenerator.generate(length, false);
            assertEquals(length, value.length());
            assertTrue(value.matches(".*[A-Z].*"));
            assertTrue(value.matches(".*[a-z].*"));
            assertTrue(value.matches(".*[2-9].*"));
            assertFalse(value.matches(".*[!@#$%&*?_-].*"));
        }
        assertThrows(IllegalArgumentException.class, () -> PasswordGenerator.generate(12, true));
    }
}

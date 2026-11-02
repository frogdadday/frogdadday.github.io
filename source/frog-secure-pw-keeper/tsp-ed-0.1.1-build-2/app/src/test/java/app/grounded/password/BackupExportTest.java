package app.grounded.password;

import org.junit.Test;
import static org.junit.Assert.*;
import java.io.*;

public class BackupExportTest {
    @Test public void closeFailureCannotReportSuccessfulExport() {
        OutputStream failing = new ByteArrayOutputStream() {
            @Override public void close() throws IOException { throw new IOException("provider close failed"); }
        };
        assertThrows(IOException.class, () -> BackupExport.write(failing, new byte[]{1, 2, 3}));
    }
    @Test public void storageFullClosesStreamAndFails() {
        boolean[] closed = {false};
        OutputStream failing = new OutputStream() {
            @Override public void write(int value) throws IOException { throw new IOException("storage full"); }
            @Override public void close() { closed[0] = true; }
        };
        assertThrows(IOException.class, () -> BackupExport.write(failing, new byte[]{1}));
        assertTrue(closed[0]);
    }
    @Test public void flushFailureClosesStreamAndFails() {
        boolean[] closed = {false};
        OutputStream failing = new ByteArrayOutputStream() {
            @Override public void flush() throws IOException { throw new IOException("flush failed"); }
            @Override public void close() { closed[0] = true; }
        };
        assertThrows(IOException.class, () -> BackupExport.write(failing, new byte[]{1}));
        assertTrue(closed[0]);
    }
    @Test public void successfulExportClosesExactContents() throws Exception {
        boolean[] closed = {false};
        ByteArrayOutputStream out = new ByteArrayOutputStream() {
            @Override public void close() { closed[0] = true; }
        };
        byte[] encrypted = {1, 2, 3};
        BackupExport.write(out, encrypted);
        assertArrayEquals(encrypted, out.toByteArray());
        assertTrue(closed[0]);
        assertThrows(IOException.class, () -> BackupExport.write(null, encrypted));
    }
}

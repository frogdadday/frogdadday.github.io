package app.grounded.password;

import android.content.*;
import android.database.Cursor;
import android.net.Uri;
import android.os.ParcelFileDescriptor;
import java.io.*;

/** Test fixture for exercising real ContentResolver I/O without driving an OEM picker. */
public final class TestDocuments extends ContentProvider {
    private volatile String lastOpenMode;
    @Override public boolean onCreate() { return true; }
    @Override public ParcelFileDescriptor openFile(Uri uri, String mode) throws FileNotFoundException {
        if (!"/backup.gpv".equals(uri.getPath())) throw new FileNotFoundException();
        lastOpenMode = mode;
        return ParcelFileDescriptor.open(new File(getContext().getCacheDir(), "fixture.gpv"), ParcelFileDescriptor.parseMode(mode));
    }
    @Override public String getType(Uri uri) { return "application/octet-stream"; }
    @Override public Cursor query(Uri uri, String[] projection, String selection, String[] args, String sort) {
        android.database.MatrixCursor result = new android.database.MatrixCursor(new String[]{"mode"});
        result.addRow(new Object[]{lastOpenMode});
        return result;
    }
    @Override public Uri insert(Uri uri, ContentValues values) { throw new UnsupportedOperationException(); }
    @Override public int delete(Uri uri, String selection, String[] args) { return 0; }
    @Override public int update(Uri uri, ContentValues values, String selection, String[] args) { return 0; }
}

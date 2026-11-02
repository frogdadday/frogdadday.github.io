package app.grounded.password;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

/** Small, deterministic catalogue helper used by the paged vault list. */
final class VaultEntryList {
    private VaultEntryList() {}

    static List<VaultData.Entry> matching(List<VaultData.Entry> entries, String query) {
        List<VaultData.Entry> result = new ArrayList<>();
        for (VaultData.Entry entry : entries) if (entry.matches(query)) result.add(entry);
        result.sort(Comparator.comparing(VaultData.Entry::title, String.CASE_INSENSITIVE_ORDER));
        return result;
    }
}

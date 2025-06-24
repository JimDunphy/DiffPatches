# diff-search.pl Usage Guide

## Installation

1. Save the script as `diff-search.pl`
2. Make it executable: `chmod +x diff-search.pl`
3. Optionally, move to your PATH: `sudo mv diff-search.pl /usr/local/bin/`

## Basic Usage Examples

### 1. Search for "htmlEncode" in your diff file
```bash
./diff-search.pl --search "htmlEncode" files.diff
```

### 2. Search with statistics
```bash
./diff-search.pl --search "htmlEncode" --stats files.diff
```

### 3. Save output to a patch file
```bash
./diff-search.pl --search "htmlEncode" --output htmlEncode-patches.diff files.diff
```

### 4. Case-insensitive search
```bash
./diff-search.pl --search "ajxstringutil" --ignore-case files.diff
```

### 5. Multiple search terms
```bash
./diff-search.pl --search "htmlEncode" --search "AjxStringUtil" files.diff
```

### 6. Verbose output with statistics
```bash
./diff-search.pl --search "htmlEncode" --verbose --stats files.diff
```

### 7. Read from stdin
```bash
cat files.diff | ./diff-search.pl --search "htmlEncode"
```

### 8. Dry run to see what would be processed
```bash
./diff-search.pl --search "htmlEncode" --dry-run files.diff
```

## Sample Output

When you run:
```bash
./diff-search.pl --search "htmlEncode" --stats files.diff
```

You'll get output like:
```
=== SEARCH STATISTICS ===
Search terms: htmlEncode
Case sensitive: true
Total files processed: 15
Files with matches: 5
Total hunks processed: 45
Hunks with matches: 8
Total matches found: 12

Files with matches:
  +++ new/./opt/zimbra/jetty_base/webapps/zimbra/js/MailCore_all.js
  +++ new/./opt/zimbra/jetty_base/webapps/zimbra/js/NewWindow_2_all.js
  +++ new/./opt/zimbra/jetty_base/webapps/zimbra/js/Startup2_all.js
  +++ new/./opt/zimbra/jetty_base/webapps/zimbra/js/Voicemail_all.js
  +++ new/./opt/zimbra/jetty_base/webapps/zimbra/js/zimbraMail/calendar/view/ZmQuickReminderDialog.js
========================
[SUCCESS] Found matches in 8 hunks across 5 files

--- old/./opt/zimbra/jetty_base/webapps/zimbra/js/MailCore_all.js	2025-04-24 21:19:32.000000000 -0700
+++ new/./opt/zimbra/jetty_base/webapps/zimbra/js/MailCore_all.js	2025-06-11 06:56:46.000000000 -0700
@@ -8880,12 +8880,12 @@
 		var attendee = this._invite.getAttendees()[0];
 		var ptst = attendee && attendee.ptst;
 		if (ptst) {
-            var names = [];
-			var dispName = attendee.d || attendee.a;
-            var sentBy = attendee.sentBy;
-            var ptstStr = null;
-            if (sentBy) names.push(attendee.sentBy);
-            names.push(dispName);
+			var names = [];
+			var dispName = AjxStringUtil.htmlEncode(attendee.d || attendee.a);
+			var sentBy = AjxStringUtil.htmlEncode(attendee.sentBy);
+			var ptstStr = null;
+			if (sentBy) names.push(AjxStringUtil.htmlEncode(attendee.sentBy));
+			names.push(dispName);
 			subs.ptstIcon = ZmCalItem.getParticipationStatusIcon(ptst);
 			switch (ptst) {
 				case ZmCalBaseItem.PSTATUS_ACCEPT:
[... more hunks ...]
```

## Applying the Patches

Once you have extracted the patches, you can apply them using:

### Option 1: Using patch command
```bash
patch -p0 < htmlEncode-patches.diff
```

### Option 2: Using git apply
```bash
git apply htmlEncode-patches.diff
```

### Option 3: Using git apply with check
```bash
# Check if patch can be applied
git apply --check htmlEncode-patches.diff

# Apply if check passes
git apply htmlEncode-patches.diff
```

## Advanced Examples

### Search for multiple patterns with regex
```bash
./diff-search.pl --search "html.*Encode" --search "AjxStringUtil\.html" files.diff
```

### Extract all calendar-related changes
```bash
./diff-search.pl --search "calendar" --ignore-case --output calendar-changes.diff files.diff
```

### Find all security-related encoding changes
```bash
./diff-search.pl --search "htmlEncode" --search "encode" --search "escape" --stats files.diff
```

## Script Options Reference

| Option | Short | Description |
|--------|-------|-------------|
| `--search PATTERN` | `-s` | Search pattern (required, can be used multiple times) |
| `--file FILE` | `-f` | Input diff file (default: stdin) |
| `--output FILE` | `-o` | Output file (default: stdout) |
| `--context LINES` | `-c` | Context lines around matches (default: 3) |
| `--ignore-case` | `-i` | Case insensitive search |
| `--stats` | `-S` | Show search statistics |
| `--verbose` | `-v` | Verbose output |
| `--dry-run` | `-n` | Show what would be done |
| `--help` | `-h` | Show help message |

## Tips and Best Practices

1. **Always use `--stats` first** to understand what you're working with
2. **Use `--dry-run`** to verify your search parameters before generating output
3. **Save important patches** to files using `--output`
4. **Test patches** in a safe environment before applying to production
5. **Use version control** to track your changes
6. **Combine with other tools** like `grep`, `awk`, or `sed` for complex filtering

## Common Use Cases

### Security Audits
Find all XSS prevention changes:
```bash
./diff-search.pl --search "htmlEncode" --search "escape" --search "sanitize" --stats files.diff
```

### Feature Implementation
Track specific feature changes:
```bash
./diff-search.pl --search "calendar" --search "appointment" --ignore-case files.diff
```

### Bug Fixes
Extract specific bug fix hunks:
```bash
./diff-search.pl --search "bug" --search "fix" --search "CVE" --ignore-case files.diff
```

### Code Refactoring
Find method rename patterns:
```bash
./diff-search.pl --search "oldMethodName" --search "newMethodName" files.diff
```

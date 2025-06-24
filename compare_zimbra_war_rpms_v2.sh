#!/bin/bash
set -euo pipefail

# === Usage ===
# Compare Zimbra WAR RPMs from backup and latest directories.
#
# Usage:
#   ./compare_zimbra_war_rpms_v2.sh <pkgname> [--backup-dir DIR] [--latest-dir DIR]
#   ./compare_zimbra_war_rpms_v2.sh --init
#   ./compare_zimbra_war_rpms_v2.sh --help
#   ./compare_zimbra_war_rpms_v2.sh --report [--backup-dir DIR] [--latest-dir DIR]
#   ./compare_zimbra_war_rpms_v2.sh --full-report [--backup-dir DIR] [--latest-dir DIR]
#   ./compare_zimbra_war_rpms_v2.sh --deep <pkgname> [--backup-dir DIR] [--latest-dir DIR]
#
# Optional Software:
#   sudo pip3 install diffoscope
#
# Options:
#   <pkgname>         Name of the Zimbra package (e.g., zimbra-mbox-webclient-war)
#   --backup-dir DIR  Path to previous backup directory (default: ~/zimbra-rpm-backup/latest)
#   --latest-dir DIR  Path to latest downloaded RPMs (default: ~/zimbra-rpm-latest)
#   --init            Install all required tools (rpm2cpio, cpio, unzip, java, wget, diffoscope)
#   --report          Report which RPMs differ based on build time
#   --full-report     Like --report, but runs full comparison for differing RPMs
#   --deep            Enable full binary diffoscope analysis (slower, more detailed)
#   --help            Show usage information

# === Environment ===
PKGNAME=""
BACKUP_DIR="${HOME}/zimbra-rpm-backup/latest"
LATEST_DIR="${HOME}/zimbra-rpm-latest"
DEEP_MODE=0

# === Argument Parsing ===
while [[ $# -gt 0 ]]; do
  case $1 in
    --backup-dir)
      BACKUP_DIR="$2"; shift 2;;
    --latest-dir)
      LATEST_DIR="$2"; shift 2;;
    --deep)
      DEEP_MODE=1; PKGNAME="$2"; shift 2;;
    --help)
      grep '^#' "$0" | cut -c 4-; exit 0;;
    --init)
      sudo apt-get install -y rpm2cpio cpio unzip default-jre wget diffoscope; exit 0;;
    --report|--full-report)
      echo "🔍 Not implemented yet."; exit 0;;
    *)
      PKGNAME="$1"; shift;;
  esac
done

if [[ -z "$PKGNAME" ]]; then
  echo "❌ Package name required. Use --help for usage."; exit 1
fi

# === Setup Workspace ===
TS=$(date +%Y%m%d_%H%M%S)
WORKSPACE="/home/jad/workspace_${PKGNAME}"
rm -rf "$WORKSPACE"
mkdir -p "$WORKSPACE"/{old,new}

OLD_RPM=$(find "$BACKUP_DIR" -name "$PKGNAME*.rpm" | sort | tail -n1)
NEW_RPM=$(find "$LATEST_DIR" -name "$PKGNAME*.rpm" | sort | tail -n1)

echo "📦 Extracting old RPM: $OLD_RPM"
rpm2cpio "$OLD_RPM" | (cd "$WORKSPACE/old" && cpio -idmu --quiet)

echo "📦 Extracting new RPM: $NEW_RPM"
rpm2cpio "$NEW_RPM" | (cd "$WORKSPACE/new" && cpio -idmu --quiet)

# === Diff .spec or script content ===
echo "📄 Extracting install scripts..."
cd "$WORKSPACE"
find . -name '*.sh' -o -name '*.xml' -o -name '*.css' | sort > all_files.txt
comm -12 <(cd old && find . -type f | sort) <(cd new && find . -type f | sort) | while read -r path; do
  if [[ -f "old/$path" && -f "new/$path" ]]; then
    if ! cmp -s "old/$path" "new/$path"; then
      mkdir -p "$(dirname "$WORKSPACE/files.diff")"
      diff -urN "old/$path" "new/$path" >> "$WORKSPACE/files.diff" || true
    fi
  fi

done

# === Deep Mode ===
if [[ "$DEEP_MODE" -eq 1 ]]; then
  echo "🔬 Running diffoscope (may take time)..."
  diffoscope "$WORKSPACE/old" "$WORKSPACE/new" > "$WORKSPACE/diffoscope.txt" || true
else
  echo "🧪 Skipping diffoscope (deep diff) by default. Use --deep to enable."
fi

# === Compare .jar files in the unpacked RPMs ===
JAR_DIFF_DIR="$WORKSPACE/jars"
mkdir -p "$JAR_DIFF_DIR"
README="$WORKSPACE/README.txt"
echo "📝 JAR Comparison Summary" > "$README"
echo "------------------------" >> "$README"
echo "" >> "$README"

find "$WORKSPACE/new" -name '*.jar' | while read -r new_jar; do
  rel_path="${new_jar#$WORKSPACE/new/}"
  old_jar="$WORKSPACE/old/$rel_path"

  if [[ -f "$old_jar" ]]; then
    if ! cmp -s "$old_jar" "$new_jar"; then
      jar_path_dir="$(dirname "$rel_path")"
      jar_base="$(basename "$new_jar" .jar)"
      echo "🔎 Examining changed jar: $jar_base"
      echo "Changed jar: $rel_path" >> "$README"

      jar_workspace="$JAR_DIFF_DIR/$jar_base"
      mkdir -p "$jar_workspace/old" "$jar_workspace/new"
      unzip -qq -o "$old_jar" -d "$jar_workspace/old"
      unzip -qq -o "$new_jar" -d "$jar_workspace/new"
      diff -urN "$jar_workspace/old" "$jar_workspace/new" > "$jar_workspace/files.diff" || true

      CFR_JAR="/usr/local/bin/cfr.jar"
      if [[ -f "$CFR_JAR" ]]; then
        echo "🧹 Decompiling changed classes in $jar_base..."
        find "$jar_workspace/new" -name '*.class' | while read -r classfile; do
          rel_class_path="${classfile#$jar_workspace/new/}"
          old_class="$jar_workspace/old/$rel_class_path"

          if [[ -f "$old_class" ]]; then
            mkdir -p "$jar_workspace/decompiled/old/$(dirname "$rel_class_path")"
            mkdir -p "$jar_workspace/decompiled/new/$(dirname "$rel_class_path")"

            java -jar "$CFR_JAR" "$old_class" --outputdir "$jar_workspace/decompiled/old" &>/dev/null || true
            java -jar "$CFR_JAR" "$classfile" --outputdir "$jar_workspace/decompiled/new" &>/dev/null || true

            java_old="$jar_workspace/decompiled/old/${rel_class_path%.class}.java"
            java_new="$jar_workspace/decompiled/new/${rel_class_path%.class}.java"

            if [[ -f "$java_old" && -f "$java_new" ]]; then
              if ! diff -q "$java_old" "$java_new" &>/dev/null; then
                diff -u "$java_old" "$java_new" > "$jar_workspace/decompiled/${rel_class_path%.class}.diff" || true
                echo "  - Decompiled class changed: $rel_class_path" >> "$README"
              else
                echo "  - Decompiled class unchanged: $rel_class_path" >> "$README"
              fi
            else
              echo "  - Could not decompile: $rel_class_path" >> "$README"
            fi
          else
            echo "  - New class only: $rel_class_path" >> "$README"
          fi
        done
      else
        echo "⚠️  CFR JAR not found at $CFR_JAR; skipping decompilation" >> "$README"
      fi
    else
      echo "⚖️  Unchanged jar: $(basename "$new_jar")"
      echo "Unchanged jar: $rel_path" >> "$README"
    fi
  else
    echo "❓ No matching old jar for: $(basename "$new_jar")"
    echo "New jar only: $rel_path" >> "$README"
  fi

done

echo "✅ Comparison complete. See workspace: $WORKSPACE"


#!/usr/bin/env perl

#------------------------------------------------------------------------------
# diff-search-patch.pl - Extract and apply filtered patch content for Zimbra
#
# Author: 6/24/2025 - JDunphy
#
# Usage Scenario:
#   Given a large patch (e.g., full files.diff), this tool allows targeted
#   extraction and patching of lines matching a search keyword (e.g., 'htmlEncode'),
#   and provides a controlled workflow for applying and packaging changes.
#
# Workflow:
#   1. Extract matching diff hunks from a full diff (e.g., from `diff -Nur old/ new/`)
#   2. Normalize line endings to avoid patching errors (CRLF vs LF)
#   3. Optionally apply the filtered patch to a working tree under `old/`
#   4. Optionally re-gzip touched .js/.jsp/.xml files
#   5. Optionally:
#        - Log a list of patched files
#        - Copy patched files to a staging directory
#        - Generate a tarball of those files
#        - Create a commit-style patch containing just the applied changes
#
# Example:
#   ./diff-search-patch.pl --search htmlEncode --file files.diff \
#       --apply \
#       --log-patched patched.log \
#       --copy-patched-to /tmp/staged-patch \
#       --tarball patched_files.tar.gz \
#       --create-commit-patch commit-ready.patch
#
# Requirements:
#   - Perl core modules: File::Temp, File::Path, File::Basename, File::Copy
#   - External tools: dos2unix, patch, gzip, diff
#
# RHEL:
#   dnf install patch
#
#------------------------------------------------------------------------------


use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case);
use File::Basename;
use Term::ANSIColor qw(colored);
use File::Temp qw(tempfile);
use Cwd qw(abs_path);

my $VERSION = "1.0";

# Default values
my $show_version = 0;
my @search_terms = ();
my $diff_file = '';
my $output_file = '';
my $case_sensitive = 1;
my $show_stats = 0;
my $verbose = 0;
my $dry_run = 0;
my $help = 0;
my $apply = 0;
my $no_gzip = 0;
my ($log_file, $commit_patch_file, $copy_dir, $tarball_file) = ('', '', '', '');
#my $tarball_file = "patched_files.tar.gz";


# Color settings
my $use_color = -t STDERR;

sub usage {
    my $script_name = basename($0);
    print <<"EOF";
Usage: $script_name [OPTIONS] --search PATTERN [DIFF_FILE]

Search for patterns in diff files and extract relevant patches.

Required:
  -s, --search PATTERN         Only include diff hunks containing this keyword
  -f, --file FILE              Full unified diff file to process (default: stdin)

Patch Actions:
  -a, --apply                  Apply filtered patch to 'old/' and optionally re-gzip files
      --no-gzip                Skip re-gzipping modified .js/.jsp/.xml files

Output Options:
  -o, --output FILE            Write filtered diff to output file (default: stdout)
      --log-patched FILE       Write list of patched files to log
      --copy-patched-to DIR    Copy patched files to specified directory
      --tarball FILE           Create .tar.gz archive of all patched files
      --create-commit-patch FILE  Create unified diff of actual changes applied

Behavior & Diagnostics:
  -i, --ignore-case            Case-insensitive match on search pattern
  -S, --stats                  Print summary stats of matched/ignored changes
  -n, --dry-run                Print what would happen, without making changes
  -v, --verbose                Enable verbose output
  -h, --help                   Show this help message and exit


OPTIONS:
    -s, --search PATTERN     Search pattern (required, can be used multiple times)
    -f, --file FILE          Input diff file (default: stdin)
    -o, --output FILE        Output file (default: stdout)
    -i, --ignore-case        Case insensitive search
    -S, --stats              Show search statistics
    -v, --verbose            Verbose output
    -n, --dry-run            Show what would be done without creating output
    -a, --apply              Apply patch directly and re-gzip .js/.jsp/.xml bundles
        --no-gzip            Skip re-gzipping after patching
    -h, --help               Show this help message


Examples:

# 1. Show stats for matches in a large diff
$0 --search htmlEncode --stats files.diff

# 2. Preview filtered diff hunks only (no patching)
$0 --search htmlEncode --file files.diff

# 3. Apply filtered patch and re-gzip affected .js/.jsp/.xml files
$0 --search htmlEncode --apply --file files.diff

# 4. Apply filtered patch, but skip gzip (leave files uncompressed)
$0 --search htmlEncode --apply --file files.diff --no-gzip

# 5. Apply patch and log modified files to a text file
$0 --search htmlEncode --apply --file files.diff \
   --log-patched patched_files.txt

# 6. Apply patch and copy changed files to a staging directory
$0 --search htmlEncode --apply --file files.diff \
   --copy-patched-to /tmp/staging_dir

# 7. Apply patch and create a tarball of all patched files
$0 --search htmlEncode --apply --file files.diff \
   --tarball patched_files.tar.gz

# 8. Apply patch and generate a commit-ready patch (unified diff)
$0 --search htmlEncode --apply --file files.diff \
   --create-commit-patch commit.patch

# 9. Full end-to-end: patch, log, copy, tarball, and commit patch
$0 --search htmlEncode --apply --file files.diff \
   --log-patched patched.txt \
   --copy-patched-to /tmp/staging \
   --tarball htmlEncode_fixes.tar.gz \
   --create-commit-patch htmlEncode.patch

EOF
}

sub log_message {
    my ($message) = @_;
    if ($verbose) {
        my $colored_msg = $use_color ? colored(['blue'], "[INFO]") : "[INFO]";
        print STDERR "$colored_msg $message\n";
    }
}

sub error_message {
    my ($message) = @_;
    my $colored_msg = $use_color ? colored(['red'], "[ERROR]") : "[ERROR]";
    print STDERR "$colored_msg $message\n";
    exit 1;
}

sub warning_message {
    my ($message) = @_;
    my $colored_msg = $use_color ? colored(['yellow'], "[WARNING]") : "[WARNING]";
    print STDERR "$colored_msg $message\n";
}

sub success_message {
    my ($message) = @_;
    my $colored_msg = $use_color ? colored(['green'], "[SUCCESS]") : "[SUCCESS]";
    print STDERR "$colored_msg $message\n";
}

sub line_matches {
    my ($line, $search_terms_ref, $case_sensitive) = @_;
    for my $search_term (@$search_terms_ref) {
        return 1 if $case_sensitive
            ? index($line, $search_term) >= 0
            : index(lc($line), lc($search_term)) >= 0;
    }
    return 0;
}

sub extract_matching_hunks {
    my ($input_handle, $search_terms_ref, $case_sensitive, $show_stats, $verbose) = @_;

    my @lines = <$input_handle>;
    chomp @lines;

    my ($total_files, $matching_files, $total_hunks, $matching_hunks, $total_matches) = (0, 0, 0, 0, 0);
    my (@output_parts, @matching_files_list);
    my $i = 0;

    while ($i < @lines) {
        my $line = $lines[$i];
        if ($line =~ /^---\s/ && $i + 1 < @lines && $lines[$i + 1] =~ /^\+\+\+\s/) {
            my $file_header   = $line . "\n" . $lines[$i + 1];
            my $filename_line = $lines[$i + 1];
            $filename_line =~ s!^\+\+\+\s+new/!!;   # strip the "+++ new/" prefix
            $filename_line =~ s!\t.*$!!;            # strip date/time after a tab
            $filename_line =~ s!^\./!!;             # strip leading "./" if any

            $total_files++;
            $i += 2;
            my (@file_hunks, $file_has_matches) = ();

            while ($i < @lines) {
                $line = $lines[$i];
                last if $line =~ /^---\s/;

                if ($line =~ /^Binary\s/) {
                    $i++;
                    next;
                }

                if ($line =~ /^@@.*@@/) {
                    my $hunk_start = $i;
                    my $hunk_has_match = 0;
                    $total_hunks++;
                    $i++;
                    while ($i < @lines) {
                        $line = $lines[$i];
                        last if $line =~ /^@@|^---\s|^Binary\s/;
                        if (line_matches($line, $search_terms_ref, $case_sensitive)) {
                            $hunk_has_match = 1;
                            $total_matches++;
                        }
                        $i++;
                    }
                    if ($hunk_has_match) {
                        my @hunk_lines = @lines[$hunk_start .. $i - 1];
                        push @file_hunks, join("\n", @hunk_lines);
                        $matching_hunks++;
                        $file_has_matches = 1;
                    }
                } else {
                    $i++;
                }
            }

            if ($file_has_matches && @file_hunks) {
                push @output_parts, $file_header . "\n" . join("\n", @file_hunks);
                $matching_files++;
                push @matching_files_list, $filename_line;
            }
        } else {
            $i++;
        }
    }

    if ($show_stats) {
        print STDERR "=== SEARCH STATISTICS ===\n";
        print STDERR "Search terms: " . join(', ', @$search_terms_ref) . "\n";
        print STDERR "Case sensitive: " . ($case_sensitive ? "true" : "false") . "\n";
        print STDERR "Total files processed: $total_files\n";
        print STDERR "Files with matches: $matching_files\n";
        print STDERR "Total hunks processed: $total_hunks\n";
        print STDERR "Hunks with matches: $matching_hunks\n";
        print STDERR "Total matches found: $total_matches\n";
        if ($matching_files > 0) {
            print STDERR "Files with matches:\n";
            for my $file (@matching_files_list) {
                print STDERR "  $file\n";
            }
        }

        print STDERR "========================\n";
    }

    return (@output_parts ? (join("\n", @output_parts) . "\n", 1, \@matching_files_list) : ('', 0, []));
}



GetOptions(
    'search|s=s'     => \@search_terms,
    'file|f=s'       => \$diff_file,
    'output|o=s'     => \$output_file,
    'ignore-case|i'  => sub { $case_sensitive = 0 },
    'stats|S'        => \$show_stats,
    'verbose|V'      => \$verbose,
    'version|v'      => \$show_version,
    'dry-run|n'      => \$dry_run,
    'apply|a'        => \$apply,
    'no-gzip'        => \$no_gzip,
    'log-patched=s'         => \$log_file,
    'create-commit-patch=s' => \$commit_patch_file,
    'copy-patched-to=s'     => \$copy_dir,
    'tarball=s'             => \$tarball_file,   # optional; see §4
    'help|h'         => \$help,
) or error_message("Error in command line arguments");

if ($show_version) {
    print "$0 version $VERSION\n";
    exit;
}

if (@ARGV && !$diff_file) {
    $diff_file = $ARGV[0];
}
if ($help) { usage(); exit 0; }
if (@search_terms == 0) {
    error_message("Search pattern is required. Use --search PATTERN");
}


my $input_handle;
if ($diff_file) {
    open($input_handle, '<', $diff_file) or error_message("Cannot open file: $diff_file");
} else {
    error_message("No input file specified and no data piped to stdin") if -t STDIN;
    $input_handle = \*STDIN;
}

if ($dry_run) {
    print STDERR "=== DRY RUN MODE ===\n";
    print STDERR "Would search for: " . join(', ', @search_terms) . "\n";
    print STDERR "Case sensitive: " . ($case_sensitive ? "true" : "false") . "\n";
    exit 0;
}

my ($output_content, $success, $matching_files_ref) =
    extract_matching_hunks($input_handle, \@search_terms, $case_sensitive, $show_stats, $verbose);
my @gzipped_files;

close($input_handle) if $diff_file;

if ($apply) {
    my ($fh, $tmp) = tempfile('diffapply_XXXX', SUFFIX => '.patch', UNLINK => 0);
    print $fh $output_content;
    close $fh;

    foreach my $f (@$matching_files_ref) {
        next unless $f =~ /\.(js|jsp|xml)$/;
        my $path = "old/$f";
        $path =~ s/\t.*$//;
        if (-f $path) {
            log_message("Normalizing line endings for: $path");
            system("dos2unix \"$path\" > /dev/null 2>&1");
        }
    }

    system("dos2unix \"$tmp\" > /dev/null 2>&1");

    success_message("Testing patch (dry-run)...");
    my $check = system("patch --dry-run -p0 < \"$tmp\" > /dev/null");
    error_message("Patch check failed; aborting.") if $check != 0;

    success_message("Applying patch...");
    my $ret = system("patch -p0 < \"$tmp\" > /dev/null");
    error_message("Patch failed (exit code $ret). See $tmp") if $ret != 0;

    unless ($no_gzip) {
        foreach my $f (@$matching_files_ref) {

            # Only gzip “bundle” files whose basename ends with *_all.js|jsp|xml
            next unless $f =~ m{(?:^|/)[^/]*all\.(js|jsp|xml)$};

            my $src = "old/$f";                 # path to patched source file
            $src =~ s/\t.*$//;                  # strip any diff timestamp
            next unless -f $src;                # sanity

            my $out = "$src.zgz";               # target bundle name
            unlink $out if -f $out;             # overwrite if it exists
            system("gzip -9c '$src' > '$out'") == 0
                or warn "gzip failed on $src → $out";

            push @gzipped_files, $out if -f $out;   # record for log/copy/tar
            success_message("Re-gzip: $src → $out");
        }
    }


use File::Path qw(make_path);
use File::Copy qw(copy);

if ($copy_dir) {
    foreach my $rel (@$matching_files_ref, @gzipped_files) {

        # Match source or gzipped files
        next unless $rel =~ /\.(js|jsp|xml|gz|zgz)$/;

        my $src;
        if ($rel =~ /^old\//) {
            $src = $rel;  # already has full path
            $rel =~ s/^old\///;  # fix for destination path
        } else {
            $src = "old/$rel";
        }

        next unless -f $src;

        my $dest = "$copy_dir/$rel";
        make_path(File::Basename::dirname($dest));
        copy($src, $dest) or warn "Copy failed $src → $dest: $!";
    }
    success_message("Copied patched files to $copy_dir");
}


use Archive::Tar;

    if ($tarball_file) {
        my $tar = Archive::Tar->new;
        $tar->add_files($_) for map { m!^old/! ? $_ : "old/$_" } (@$matching_files_ref, @gzipped_files);
        $tar->write($tarball_file, COMPRESS_GZIP);
        success_message("Tarball created: $tarball_file");
    }

    if ($log_file) {
        open my $lf, '>', $log_file or warn "Cannot write log $log_file: $!";
        print $lf "$_\n" for (@$matching_files_ref,@gzipped_files);
        close $lf;
        success_message("Patched-file list written to $log_file");
    }

    unlink $tmp;
    exit 0;
}

if ($success) {
    if ($output_file) {
        open(my $out_fh, '>', $output_file) or error_message("Cannot write to file: $output_file");
        print $out_fh $output_content;
        close $out_fh;
        success_message("Patch file created: $output_file");
        print STDERR "To apply the patch, run:\n  patch -p0 < $output_file\n";
    } else {
        print $output_content;
    }
    exit 0;
} else {
    exit 1;
}


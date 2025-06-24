#!/usr/bin/env perl

#
# Author: 6/24/2025 - JDunphy
#
# Script to build patches from something like this:
#    diff -urN "old/$path" "new/$path" > files.diff
#

# diff-search-fixed.pl - Fixed version with better hunk detection
# Version: 1.1 - Perl

use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case);
use File::Basename;
use Term::ANSIColor qw(colored);

# Default values
my @search_terms = ();
my $diff_file = '';
my $output_file = '';
my $case_sensitive = 1;
my $show_stats = 0;
my $verbose = 0;
my $dry_run = 0;
my $help = 0;

# Color settings
my $use_color = -t STDERR;

sub usage {
    my $script_name = basename($0);
    print <<"EOF";
Usage: $script_name [OPTIONS] --search PATTERN [DIFF_FILE]

Search for patterns in diff files and extract relevant patches.

OPTIONS:
    -s, --search PATTERN     Search pattern (required, can be used multiple times)
    -f, --file FILE         Input diff file (default: stdin)
    -o, --output FILE       Output file (default: stdout)
    -i, --ignore-case       Case insensitive search
    -S, --stats             Show search statistics
    -v, --verbose           Verbose output
    -n, --dry-run           Show what would be done without creating output
    -h, --help              Show this help message

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
        if ($case_sensitive) {
            return 1 if index($line, $search_term) >= 0;
        } else {
            return 1 if index(lc($line), lc($search_term)) >= 0;
        }
    }
    return 0;
}

sub extract_matching_hunks {
    my ($input_handle, $search_terms_ref, $case_sensitive, $show_stats, $verbose) = @_;
    
    # Read entire file into memory for better processing
    my @lines = <$input_handle>;
    chomp @lines;
    
    my $total_files = 0;
    my $matching_files = 0;
    my $total_hunks = 0;
    my $matching_hunks = 0;
    my $total_matches = 0;
    
    my @output_parts = ();
    my @matching_files_list = ();
    
    log_message("Processing diff file...");
    
    my $i = 0;
    while ($i < @lines) {
        my $line = $lines[$i];
        
        # Look for file header pairs
        if ($line =~ /^---\s/ && $i + 1 < @lines && $lines[$i + 1] =~ /^\+{3}\s/) {
            my $file_header = $line . "\n" . $lines[$i + 1];
            my $filename = $lines[$i + 1];
            $total_files++;
            $i += 2; # Skip both header lines
            
            log_message("Processing file: $filename");
            
            # Collect all hunks for this file
            my @file_hunks = ();
            my $file_has_matches = 0;
            
            # Process hunks until we hit the next file or end of input
            while ($i < @lines) {
                $line = $lines[$i];
                
                # Stop if we hit another file header
                if ($line =~ /^---\s/) {
                    last;
                }
                
                # Skip binary file indicators
                if ($line =~ /^Binary\s/) {
                    $i++;
                    next;
                }
                
                # Process hunk
                if ($line =~ /^@@.*@@/) {
                    my $hunk_start = $i;
                    my $hunk_has_match = 0;
                    $total_hunks++;
                    $i++; # Move past hunk header
                    
                    # Read hunk content until next @@ or file header
                    while ($i < @lines) {
                        $line = $lines[$i];
                        
                        # Stop at next hunk or file
                        if ($line =~ /^@@/ || $line =~ /^---\s/ || $line =~ /^Binary\s/) {
                            last;
                        }
                        
                        # Check for matches in this line
                        if (line_matches($line, $search_terms_ref, $case_sensitive)) {
                            $hunk_has_match = 1;
                            $total_matches++;
                            log_message("Match found: $line");
                        }
                        
                        $i++;
                    }
                    
                    # If this hunk had matches, save it
                    if ($hunk_has_match) {
                        my $hunk_end = $i - 1;
                        my @hunk_lines = @lines[$hunk_start..$hunk_end];
                        push @file_hunks, join("\n", @hunk_lines);
                        $matching_hunks++;
                        $file_has_matches = 1;
                    }
                } else {
                    $i++;
                }
            }
            
            # If file had matching hunks, add to output
            if ($file_has_matches && @file_hunks > 0) {
                push @output_parts, $file_header . "\n" . join("\n", @file_hunks);
                $matching_files++;
                push @matching_files_list, $filename;
            }
            
        } else {
            $i++;
        }
    }
    
    # Output statistics if requested
    if ($show_stats) {
        print STDERR "=== SEARCH STATISTICS ===\n";
        print STDERR "Search terms: " . join(', ', @$search_terms_ref) . "\n";
        print STDERR "Case sensitive: " . ($case_sensitive ? "true" : "false") . "\n";
        print STDERR "Total files processed: $total_files\n";
        print STDERR "Files with matches: $matching_files\n";
        print STDERR "Total hunks processed: $total_hunks\n";
        print STDERR "Hunks with matches: $matching_hunks\n";
        print STDERR "Total matches found: $total_matches\n";
        print STDERR "\n";
        if ($matching_files > 0) {
            print STDERR "Files with matches:\n";
            for my $file (@matching_files_list) {
                print STDERR "  $file\n";
            }
        }
        print STDERR "========================\n";
    }
    
    # Return results
    if (@output_parts > 0) {
        my $output_content = join("\n", @output_parts) . "\n";
        success_message("Found matches in $matching_hunks hunks across $matching_files files");
        return ($output_content, 1);
    } else {
        warning_message("No matches found for search terms: " . join(', ', @$search_terms_ref));
        return ('', 0);
    }
}

# Parse command line arguments
GetOptions(
    'search|s=s'     => \@search_terms,
    'file|f=s'       => \$diff_file,
    'output|o=s'     => \$output_file,
    'ignore-case|i'  => sub { $case_sensitive = 0; },
    'stats|S'        => \$show_stats,
    'verbose|v'      => \$verbose,
    'dry-run|n'      => \$dry_run,
    'help|h'         => \$help,
) or error_message("Error in command line arguments");

# Handle remaining arguments (diff file)
if (@ARGV && !$diff_file) {
    $diff_file = $ARGV[0];
}

# Show help if requested
if ($help) {
    usage();
    exit 0;
}

# Validate required arguments
if (@search_terms == 0) {
    error_message("Search pattern is required. Use --search PATTERN");
}

# Determine input source
my $input_handle;
my $input_source;

if ($diff_file) {
    if (!-f $diff_file) {
        error_message("Diff file not found: $diff_file");
    }
    open($input_handle, '<', $diff_file) or error_message("Cannot open file: $diff_file: $!");
    $input_source = $diff_file;
    log_message("Reading from file: $diff_file");
} else {
    if (-t STDIN) {
        error_message("No input file specified and no data piped to stdin");
    }
    $input_handle = \*STDIN;
    $input_source = "stdin";
    log_message("Reading from stdin");
}

# Show dry run information
if ($dry_run) {
    print STDERR "=== DRY RUN MODE ===\n";
    print STDERR "Would search for: " . join(', ', @search_terms) . "\n";
    print STDERR "Input: $input_source\n";
    print STDERR "Output: " . ($output_file || "stdout") . "\n";
    print STDERR "Case sensitive: " . ($case_sensitive ? "true" : "false") . "\n";
    print STDERR "===================\n";
    exit 0;
}

# Extract matching hunks
my ($output_content, $success) = extract_matching_hunks($input_handle, \@search_terms, $case_sensitive, $show_stats, $verbose);

# Close file handle if we opened it
if ($diff_file) {
    close($input_handle);
}

# Output results
if ($success) {
    if ($output_file) {
        log_message("Writing output to: $output_file");
        open(my $out_fh, '>', $output_file) or error_message("Cannot write to file: $output_file: $!");
        print $out_fh $output_content;
        close($out_fh);
        success_message("Patch file created: $output_file");
        print STDERR "To apply the patch, run:\n";
        print STDERR "  patch -p0 < $output_file\n";
        print STDERR "or:\n";
        print STDERR "  git apply $output_file\n";
    } else {
        print $output_content;
    }
    exit 0;
} else {
    exit 1;
}

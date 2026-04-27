# frozen_string_literal: true

# sweep-scratchpads.rb - Garbage collection for SADD scratchpad diagnostic files
#
# Usage:
#   ruby sweep-scratchpads.rb [options]
#
# Options:
#   --dry-run    List files that would be deleted without removing them
#   --ttl HOURS  Override default 24-hour TTL (default: 24)
#   --help       Show this help message
#
# Description:
#   Deletes scratchpad files (.specs/scratchpad/*.md) older than the TTL threshold.
#   Designed to be run at session start or explicitly via cleanup command.
#
# Exit codes:
#   0 - Success (files deleted or dry-run completed)
#   1 - Error (not in a git repository, invalid options)

require "fileutils"
require "optparse"
require "time"

DEFAULT_TTL_HOURS = 24
SCRATCHPAD_DIR = ".specs/scratchpad"

class ScratchpadSweeper
  attr_reader :dry_run, :ttl_seconds, :deleted_count, :kept_count

  def initialize(dry_run:, ttl_hours:)
    @dry_run = dry_run
    @ttl_seconds = ttl_hours * 3600
    @deleted_count = 0
    @kept_count = 0
  end

  def run
    unless git_repo?
      warn "Error: Not in a git repository"
      return false
    end

    scratchpad_dir = File.join(repo_root, SCRATCHPAD_DIR)

    unless Dir.exist?(scratchpad_dir)
      puts "No scratchpad directory found at #{SCRATCHPAD_DIR}"
      return true
    end

    sweep_directory(scratchpad_dir)
    report
    true
  end

  private

  def git_repo?
    system("git rev-parse --is-inside-work-tree > /dev/null 2>&1")
  end

  def repo_root
    @repo_root ||= `git rev-parse --show-toplevel`.strip
  end

  def sweep_directory(dir)
    cutoff_time = Time.now - @ttl_seconds

    Dir.glob(File.join(dir, "*.md")).each do |file|
      mtime = File.mtime(file)

      if mtime < cutoff_time
        delete_file(file, mtime)
      else
        @kept_count += 1
      end
    end
  end

  def delete_file(file, mtime)
    age_hours = ((Time.now - mtime) / 3600).round(1)

    if @dry_run
      puts "[DRY-RUN] Would delete: #{File.basename(file)} (age: #{age_hours}h)"
    else
      File.delete(file)
      puts "Deleted: #{File.basename(file)} (age: #{age_hours}h)"
    end

    @deleted_count += 1
  end

  def report
    action = @dry_run ? "Would delete" : "Deleted"
    puts "-" * 40
    puts "#{action}: #{@deleted_count} file(s)"
    puts "Kept: #{@kept_count} file(s) (under TTL threshold)"
  end
end

# CLI handling
def parse_options
  options = { dry_run: false, ttl_hours: DEFAULT_TTL_HOURS }

  parser = OptionParser.new do |opts|
    opts.banner = "Usage: ruby sweep-scratchpads.rb [options]"

    opts.on("--dry-run", "List files that would be deleted without removing them") do
      options[:dry_run] = true
    end

    opts.on("--ttl HOURS", Integer, "Override default TTL in hours (default: #{DEFAULT_TTL_HOURS})") do |hours|
      options[:ttl_hours] = hours
    end

    opts.on("-h", "--help", "Show this help message") do
      puts opts
      exit 0
    end
  end

  parser.parse!
  options
rescue OptionParser::InvalidOption => e
  warn "Error: #{e.message}"
  warn "Use --help for usage information"
  exit 1
end

# Main execution
if __FILE__ == $PROGRAM_NAME
  options = parse_options

  sweeper = ScratchpadSweeper.new(
    dry_run: options[:dry_run],
    ttl_hours: options[:ttl_hours]
  )

  success = sweeper.run
  exit(success ? 0 : 1)
end

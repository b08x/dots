#!/usr/bin/env ruby
# github_issues.rb - Create GitHub issues from markdown backlog and generate sprint reports

# frozen_string_literal: true

# == GitHub Issues Script
#
# This script provides functionalities to interact with GitHub issues based on a
# markdown backlog file. It can:
#
# 1.  **Create Issues**: Parse a markdown table of tasks and create corresponding
#     issues in a specified GitHub repository using the `gh` CLI.
# 2.  **Generate Sprint Reports**: Extract tasks for a specific sprint from the
#     markdown file and generate a summary report.
# 3.  **Export Tasks**: Export tasks (optionally filtered) from the backlog
#     to CSV or JSON format.
#
# It uses command-line options to specify actions and parameters.
# Assumes `gh` CLI is installed and authenticated.

lib_dir = File.expand_path(File.join(__dir__, '..', 'lib'))
$LOAD_PATH.unshift lib_dir unless $LOAD_PATH.include?(lib_dir)

require 'memexrag/logging' # Assuming this is your custom logging library
include Logging

require 'json'
require 'optparse'
require 'csv'
require 'shellwords' # For safely escaping command arguments

# @!parse
#   # Command-line options storage
#   # @return [Hash]
options = {}

# Parse command line options
options = {
  dry_run: false,
  action: 'create' # Default action
}

OptionParser.new do |opts|
  opts.banner = "Usage: github_issues.rb [options]"

  opts.on("--file FILE", "Path to backlog markdown file (required)") { |v| options[:file] = v }
  opts.on("--repo OWNER/REPO", "GitHub repository (e.g., 'owner/repository') (required for issue creation)") { |v| options[:repo] = v }
  opts.on("--dry-run", "Run without creating actual issues (prints gh commands)") { options[:dry_run] = true }
  opts.on("--sprint NUMBER", "Generate sprint report for given number") { |v| options[:sprint] = v; options[:action] = 'report' }
  opts.on("--export [FORMAT]", %w[csv json], "Export issues to CSV or JSON (default: csv)") do |v|
    options[:export] = v || 'csv'
    options[:action] = 'export'
  end
  opts.on("--status STATUS", "Filter by status (for reports/exports)") { |v| options[:status] = v }
end.parse!

# Validate required inputs
unless options[:file] && File.exist?(options[:file])
  logger.fatal "Error: Backlog file not found or not specified. Use --file FILE."
  exit 1
end

if options[:action] == 'create' && options[:repo].nil?
  logger.fatal "Error: GitHub repository (--repo OWNER/REPO) is required for issue creation."
  exit 1
end

# Read backlog file
content = File.read(options[:file])

# Parse the markdown table (reusing BacklogParser from gitlab_issues.rb)
class BacklogParser
  attr_reader :tasks, :headers

  # Initializes a new BacklogParser.
  #
  # @param markdown_content [String] The raw markdown content of the backlog file.
  def initialize(markdown_content)
    @markdown_content = markdown_content
    @tasks = []
    @headers = []
    parse
  end

  # Parses the markdown content to extract tasks.
  # It looks for a table with a 'Task ID' header and processes subsequent rows.
  # Populates `@tasks` with an array of hashes, where each hash represents a task,
  # and `@headers` with an array of strings representing the table column headers.
  #
  # Headers are converted to lowercase, snake_case keys in the task hashes.
  # Tasks are only added if they have a non-empty 'task_id'.
  #
  # @return [void]
  def parse
    lines = @markdown_content.split("\n")
    header_index = lines.find_index { |line| line.start_with?('|') && line.include?('Task ID') }
    return if header_index.nil?

    header_line = lines[header_index]
    @headers = header_line.split('|').map(&:strip).reject(&:empty?)

    current_index = header_index + 2 # Skip separator line

    while current_index < lines.size && lines[current_index].start_with?('|')
      columns = lines[current_index].split('|').map(&:strip).reject(&:empty?)

      if columns.size >= @headers.size
        task = {}
        @headers.each_with_index do |header, idx|
          task[header.downcase.gsub(/\s+/, '_')] = columns[idx] if idx < columns.size
        end
        @tasks << task if task['task_id'] && !task['task_id'].empty?
      end
      current_index += 1
    end
  end

  # Retrieves tasks associated with a specific sprint number.
  #
  # @param sprint_number [String, Integer] The sprint number to filter tasks by.
  # @return [Array<Hash>] An array of task hashes belonging to the specified sprint.
  def tasks_by_sprint(sprint_number)
    sprint_section = @markdown_content.match(/Sprint #{sprint_number}.*?:(.*?)(?:Sprint \d|$)/m)
    return [] unless sprint_section

    task_ids = sprint_section[1].scan(/([A-Z]+-\d+)/).flatten
    @tasks.select { |task| task_ids.include?(task['task_id']) }
  end

  # Filters tasks based on the provided criteria.
  #
  # @param filters [Hash] A hash of filters to apply.
  # @option filters [String] :status Filter tasks by their 'status' field.
  # @option filters [String] :milestone Filter tasks by their 'milestone' field.
  # @option filters [String, Integer] :sprint Filter tasks by sprint number.
  # @return [Array<Hash>] An array of task hashes that match all applied filters.
  def filtered_tasks(filters = {})
    filtered = @tasks.dup # Work on a copy

    if filters[:status]
      filtered.select! { |task| task['status']&.strip&.casecmp(filters[:status].strip)&.zero? }
    end

    if filters[:milestone] # This filter might be less relevant if milestones are handled by gh create
      filtered.select! { |task| task['milestone']&.strip&.casecmp(filters[:milestone].strip)&.zero? }
    end

    # Sprint filter should apply to the tasks from the backlog, not override other filters
    if filters[:sprint]
      sprint_task_ids = tasks_by_sprint(filters[:sprint]).map { |t| t['task_id'] }
      filtered.select! { |task| sprint_task_ids.include?(task['task_id']) }
    end
    filtered
  end
end

# Handles the creation of issues in GitHub using `gh` CLI.
class GitHubIssueCreator
  # Initializes a new GitHubIssueCreator.
  #
  # @param options [Hash] Configuration options.
  # @option options [String] :repo The GitHub repository in 'OWNER/REPO' format.
  # @option options [Boolean] :dry_run If true, simulates issue creation.
  def initialize(options)
    @repo = options[:repo]
    @dry_run = options[:dry_run]
  end

  # Creates a GitHub issue based on a task hash using `gh` CLI.
  #
  # @param task [Hash] A hash representing a task.
  #   Expected keys: 'task_id', 'category', 'description', 'main_grouping' (optional),
  #   'milestone' (optional, should be GitHub milestone name or number).
  # @return [Hash] A result hash.
  #   @option return [Boolean] :success True if the operation was successful or if it's a dry run.
  #   @option return [String] :task_id The ID of the task being processed.
  #   @option return [String] :output The output from the `gh` command (if successful and not dry_run).
  #   @option return [String] :error An error message if the creation failed.
  #   @option return [String] :command The `gh` command that was (or would be) executed.
  def create_issue(task)
    title = "[#{task['task_id']}] #{task['category']}: #{task['description']}"
    title = "#{title[0..246]}..." if title.length > 250 # GitHub title limit is 256, give some room

    body = task['description'] || "No description provided." # gh requires a body or use --body-file

    labels = []
    labels << task['category'].downcase.gsub(/\s+/, '-').gsub(/[^a-z0-9_:\-\.\?\&]+/, '') if task['category']
    if task['main_grouping'] && task['main_grouping'] != task['category']
      group_label = task['main_grouping'].downcase.gsub(/\s+/, '-').gsub(/[^a-z0-9_:\-\.\?\&]+/, '')
      labels << group_label unless labels.include?(group_label)
    end

    command_parts = ["gh issue create"]
    command_parts << "--repo #{Shellwords.escape(@repo)}"
    command_parts << "--title #{Shellwords.escape(title)}"
    command_parts << "--body #{Shellwords.escape(body)}"
    command_parts << "--label #{Shellwords.escape(labels.join(','))}" unless labels.empty?
    command_parts << "--milestone #{Shellwords.escape(task['milestone'])}" if task['milestone'] && !task['milestone'].strip.empty?

    command = command_parts.join(' ')

    logger.info "-" * 40
    logger.info "Processing Task ID: #{task['task_id']}"
    logger.info "  Title: #{title}"
    logger.info "  Labels: #{labels.join(', ')}" if labels.any?
    logger.info "  Milestone: #{task['milestone']}" if task['milestone'] && !task['milestone'].strip.empty?

    if @dry_run
      logger.info "  Dry run: Would execute: #{command}"
      return { success: true, dry_run: true, task_id: task['task_id'], command: command }
    end

    logger.info "  Executing: #{command}"
    output = `#{command} 2>&1` # Capture both stdout and stderr
    status = $?.exitstatus

    if status.zero?
      logger.info "  Successfully created issue for #{task['task_id']}. Output: #{output.strip}"
      return { success: true, task_id: task['task_id'], output: output.strip, command: command }
    else
      logger.error "  Error creating issue for #{task['task_id']}: `gh` command failed with status #{status}."
      logger.error "  Output: #{output.strip}"
      return { success: false, task_id: task['task_id'], error: output.strip, command: command }
    end
  rescue StandardError => e
    logger.error "  Exception creating issue for #{task['task_id']}: #{e.message}"
    return { success: false, task_id: task['task_id'], error: e.message, command: command }
  end
end

# Main script execution
backlog = BacklogParser.new(content)

case options[:action]
when 'create'
  creator = GitHubIssueCreator.new(options)
  pending_tasks = backlog.filtered_tasks(status: 'Pending') # Assuming 'Pending' status means it needs creation

  success_count = 0
  error_count = 0

  logger.info "Found #{pending_tasks.size} pending tasks in backlog for issue creation."

  pending_tasks.each do |task|
    result = creator.create_issue(task)
    if result[:success]
      success_count += 1
    else
      error_count += 1
    end
  end

  logger.info "-" * 40
  if options[:dry_run]
    logger.info "Dry run complete. Would have attempted to create #{pending_tasks.size} issues."
  else
    logger.info "Attempted to create #{pending_tasks.size} issues: #{success_count} succeeded, #{error_count} failed."
  end

when 'report'
  unless options[:sprint]
    logger.error "Sprint number required for sprint report. Use --sprint NUMBER."
    exit 1
  end

  sprint_tasks = backlog.tasks_by_sprint(options[:sprint])

  if sprint_tasks.empty?
    logger.warn "No tasks found for Sprint #{options[:sprint]} in the markdown backlog."
    exit 0
  end

  puts "# Sprint #{options[:sprint]} Report (from Markdown Backlog)"
  puts "\n## Tasks Overview"
  total = sprint_tasks.size
  status_counts = sprint_tasks.group_by { |t| t['status'] || 'N/A' }.transform_values(&:count)

  puts "- Total Tasks: #{total}"
  status_counts.each do |status, count|
    percentage = total.positive? ? (count.to_f / total * 100).round(1) : 0
    puts "- #{status}: #{count} (#{percentage}%)"
  end

  puts "\n## Tasks Breakdown"
  puts "\n| Task ID | Description | Status | Category | Milestone |"
  puts "|---------|-------------|--------|----------|-----------|"
  sprint_tasks.each do |task|
    puts "| #{task['task_id']} | #{task['description']} | #{task['status']} | #{task['category']} | #{task['milestone'] || ''} |"
  end

when 'export'
  filter_options = {}
  filter_options[:status] = options[:status] if options[:status]
  filter_options[:sprint] = options[:sprint] if options[:sprint] # Note: sprint filter is from markdown

  tasks_to_export = backlog.filtered_tasks(filter_options)

  if tasks_to_export.empty?
    logger.warn "No tasks found matching the filter criteria for export from the markdown backlog."
    exit 0
  end

  case options[:export]
  when 'csv'
    CSV(STDOUT) do |csv| # Output CSV to STDOUT
      csv << backlog.headers # Use original headers from markdown
      tasks_to_export.each do |task|
        row = backlog.headers.map { |h| task[h.downcase.gsub(/\s+/, '_')] || '' }
        csv << row
      end
    end
  when 'json'
    puts JSON.pretty_generate(tasks_to_export)
  else
    logger.error "Unsupported export format: #{options[:export]}. Supported formats: csv, json."
    exit 1
  end
end
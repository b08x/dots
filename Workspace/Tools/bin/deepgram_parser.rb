#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "optparse"

# This class provides methods for parsing and extracting information from Deepgram JSON output.
class DeepgramParser
  attr_reader :paragraphs, :intents, :topics, :transcript

  # Initializes a new Deepgram instance.
  #
  # @param file [String] The path to the Deepgram JSON file.
  def initialize(file)
    raise ArgumentError, "File not found: #{file}" unless File.exist?(file)

    @file = file
    @json_data = JSON.parse(File.read(file))
    @paragraphs = []
    @intents = []
    @topics = []
    parse_json
  rescue JSON::ParserError => e
    raise "Invalid JSON file: #{e.message}"
  end

  # Parses the Deepgram JSON data.
  #
  # @return [void]
  def parse_json
    extract_transcript
    extract_paragraphs
    extract_topics
    extract_intents
  end

  # Returns words with their confidence scores
  #
  # @return [Array<Hash>] Array of words with confidence scores
  def words_with_confidence
    @json_data["results"]["channels"][0]["alternatives"][0]["words"].map do |word|
      { word: word["word"], confidence: word["confidence"] }
    end
  end

  # Returns segmented sentences
  #
  # @return [Array<Hash>] Array of sentences
  def segmented_sentences
    @json_data["results"]["channels"][0]["alternatives"][0]["paragraphs"]["paragraphs"]
      .flat_map { |p| p["sentences"] }
      .map { |sentence| { text: sentence["text"] } }
  end

  # Returns paragraphs as arrays of sentences
  #
  # @return [Array<Hash>] Array of paragraphs containing sentence arrays
  def paragraphs_as_sentences
    @json_data["results"]["channels"][0]["alternatives"][0]["paragraphs"]["paragraphs"]
      .map do |p|
        { paragraph: p["sentences"].map { |s| s["text"] } }
      end
  end

  # Returns segments with their labeled topics
  #
  # @return [Array<Hash>] Array of segments with topics
  def segments_with_topics
    @json_data["results"]["topics"]["segments"].map do |seg|
      {
        text: seg["text"],
        topics: seg["topics"].map { |t| { topic: t["topic"] } }
      }
    end
  end

  # Returns segments with their labeled intents
  #
  # @return [Array<Hash>] Array of segments with intents
  def segments_with_intents
    @json_data["results"]["intents"]["segments"].map do |seg|
      {
        text: seg["text"],
        intents: seg["intents"].map { |i| { intent: i["intent"] } }
      }
    end
  end

  # Formats the paragraphs as SRT subtitles
  #
  # @return [String] The SRT formatted output
  def to_srt
    output = []
    @paragraphs.each_with_index do |p, index|
      output << (index + 1).to_s
      output << "#{format_timestamp(
        p[:start].split(':').map(&:to_i).inject(0) do |sum, time|
          (sum * 60) + time
        end,
        true
      )} --> #{format_timestamp(
        p[:end].split(':').map(&:to_i).inject(0) do |sum, time|
          (sum * 60) + time
        end,
        true
      )}"
      output << p[:text]
      output << ""
    end
    output.join("\n")
  end

  # Formats all the data as markdown
  #
  # @return [String] The markdown formatted output
  def to_markdown
    output = ["# Deepgram Analysis Results\n"]

    output << "## Full Transcript\n\n#{@transcript}\n" if @transcript

    unless @paragraphs.empty?
      output << "## Paragraphs\n"
      @paragraphs.each do |p|
        output << "### #{p[:start]} -> #{p[:end]}\n"
        output << "#{p[:text]}\n\n"
      end
    end

    unless @intents.empty?
      output << "## Intents\n"
      @intents.each do |i|
        output << "- #{i[:start]} -> #{i[:end]}: #{i[:intent]}\n"
      end
      output << "\n"
    end

    unless @topics.empty?
      output << "## Topics\n"
      @topics.each do |t|
        output << "- #{t[:topic]}\n"
      end
      output << "\n"
    end

    if @json_data["results"]["channels"][0]["alternatives"][0]["words"]
      output << "## Words with Confidence\n"
      words_with_confidence.each do |w|
        output << "- #{w[:word]}: #{w[:confidence]}\n"
      end
      output << "\n"
    end

    if @json_data["results"]["channels"][0]["alternatives"][0]["paragraphs"]["paragraphs"]
      output << "## Segmented Sentences\n"
      segmented_sentences.each do |s|
        output << "- #{s[:text]}\n"
      end
    end

    output.join("\n")
  end

  private

  # Extracts the transcript from the JSON data.
  def extract_transcript
    @transcript = @json_data["results"]["channels"][0]["alternatives"][0]["transcript"]
  end

  # Extracts paragraphs from the JSON data.
  def extract_paragraphs
    @json_data["results"]["channels"][0]["alternatives"][0]["paragraphs"]["paragraphs"].each do |paragraph|
      sentences = paragraph["sentences"].map { |sentence| sentence["text"] }
      start_time = format_timestamp(paragraph["sentences"].first["start"])
      end_time = format_timestamp(paragraph["sentences"].last["end"])
      @paragraphs << { text: sentences.join(" "), start: start_time, end: end_time }
    end
  end

  # Extracts topics from the JSON data.
  def extract_topics
    @json_data["results"]["topics"]["segments"].each do |seg|
      @topics << { topic: seg["topics"][0]["topic"] }
    end
    @topics.uniq!
  end

  # Extracts intents from the JSON data.
  def extract_intents
    @json_data["results"]["intents"]["segments"].each do |seg|
      start_time = format_timestamp(seg["start"])
      end_time = format_timestamp(seg["end"])
      @intents << { intent: seg["intents"][0]["intent"], start: start_time, end: end_time }
    end
    @intents.uniq!
  end

  # Formats a timestamp from seconds to HH:MM:SS.
  #
  # @param seconds [Float] The timestamp in seconds.
  # @return [String] The formatted timestamp.
  def format_timestamp(seconds, include_ms=false)
    return nil if seconds.nil?

    hours = (seconds / 3600).to_i
    minutes = ((seconds % 3600) / 60).to_i
    secs = (seconds % 60).to_i
    ms = ((seconds % 1) * 1000).to_i

    if include_ms
      format("%02d:%02d:%02d,%03d", hours, minutes, secs, ms)
    else
      format("%02d:%02d:%02d", hours, minutes, secs)
    end
  rescue StandardError => e
    puts "Error formatting timestamp: #{e.message}"
    nil
  end
end

def select_file
  cmd = "yad --file --title='Select Deepgram JSON file' --file-filter='JSON files | *.json'"
  selected = `#{cmd}`.strip
  exit(1) if selected.empty? # User cancelled

  if File.basename(selected) == "analyzed_segments.json"
    keys_cmd = "yad --form --title=\"Select JSON Keys\" \
      --field=\"Segment Identifier:CHK\" \
      --field=\"Start Time of Segment:CHK\" \
      --field=\"End Time of Segment:CHK\" \
      --field=\"Segment Transcript:CHK\" \
      --field=\"Segment Topic:CHK\" \
      --field=\"Relevant Keywords:CHK\" \
      --field=\"AI Analysis of Segment:CHK\" \
      --field=\"Software Detected in Segment:CHK\" \
      --field=\"List of Software Detections:CHK\""

    key_selection = `#{keys_cmd}`.strip
    exit(1) if key_selection.empty? # User cancelled

    # Parse the JSON file
    json_data = JSON.parse(File.read(selected))

    # Map form fields to JSON keys
    field_map = {
      "Segment Identifier" => "segment_id",
      "Start Time of Segment" => "start_time",
      "End Time of Segment" => "end_time",
      "Segment Transcript" => "transcript",
      "Segment Topic" => "topic",
      "Relevant Keywords" => "keywords",
      "AI Analysis of Segment" => "gemini_analysis",
      "Software Detected in Segment" => "software_detected",
      "List of Software Detections" => "software_detections"
    }

    # Get selected fields (TRUE/FALSE values)
    selected_fields = key_selection.split("|")

    # Display selected fields for each segment
    json_data.each do |segment|
      puts "\n=== Segment ===\n"
      field_map.each_with_index do |(field_name, json_key), index|
        next unless selected_fields[index] == "TRUE"

        value = segment[json_key]
        # Format arrays nicely
        value = value.join(", ") if value.is_a?(Array)
        puts "#{field_name}: #{value}"
      end
      puts "\n"
    end

    exit 0
  end

  selected
end

def select_options
  cmd = "yad --form --title='Select Options' \
    --field='Show in console instead of writing to file:CHK' \
    --field='Output in SRT format instead of markdown:CHK'"

  result = `#{cmd}`.strip
  return {} if result.empty? # User cancelled

  values = result.split("|")
  {
    console: values[0] == "TRUE",
    srt: values[1] == "TRUE"
  }
end

# Command line interface
if __FILE__ == $PROGRAM_NAME
  options = {}

  parser = OptionParser.new do |opts|
    opts.banner = "Usage: #{File.basename($PROGRAM_NAME)} [options] json_file"

    opts.on("-c", "--console", "Show output in console instead of writing to file") do
      options[:console] = true
    end

    opts.on("--srt", "Output in SRT format instead of markdown") do
      options[:srt] = true
    end

    opts.on("-h", "--help", "Show this help message") do
      puts opts
      exit
    end
  end

  begin
    parser.parse!

    if ARGV.empty?
      json_file = select_file
      options = select_options
    else
      json_file = ARGV[0]
    end
    deepgram = DeepgramParser.new(json_file)

    # Show all information if no specific options are provided or --all is used
    show_all = options[:all] || options.empty?

    # Generate output filename based on input filename
    base_name = File.basename(json_file, ".*")
    output_file = if options[:srt]
                    File.join(File.dirname(json_file), "#{base_name}.srt")
                  else
                    File.join(File.dirname(json_file), "#{base_name}_analysis.md")
                  end

    # Generate and write output
    content = if options[:srt]
                deepgram.to_srt
              else
                deepgram.to_markdown
              end

    if options[:console]
      puts content
    else
      File.write(output_file, content)
      puts "Output written to: #{output_file}"
    end
  rescue StandardError => e
    puts "Error: #{e.message}"
    exit 1
  end
end

#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "optparse"
require "pp"

# ChatLogParser - Parses chat history logs from JSONL files
class ChatLogParser
  attr_reader :messages

  def initialize(file)
    raise ArgumentError, "File not found: #{file}" unless File.exist?(file)

    @file = file
    @messages = []
    parse_jsonl
  rescue JSON::ParserError => e
    raise "Invalid JSON file: #{e.message}"
  end

  def parse_jsonl
    File.foreach(@file) do |line|
      data = JSON.parse(line)
      @messages << {
        timestamp: data["send_date"],
        sender: data["name"],
        message: data["mes"],
        type: determine_type(data),
        extra: {
          model: data.dig("extra", "model"),
          token_count: data.dig("extra", "token_count")
        }
      }
    end
  end

  def determine_type(data)
    return "system" if data["is_system"]
    return "user" if data["is_user"]

    "bot"
  end

  def filter_messages(type: nil, sender: nil)
    @messages.select do |msg|
      (type.nil? || msg[:type] == type) && (sender.nil? || msg[:sender] == sender)
    end
  end

  def to_json(*_args)
    # JSON.pretty_generate(@messages)
    pp @messages
  end
end

# Command-line interface
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: chat_log_parser.rb [options]"
  opts.on("-f", "--file FILE", "Path to chat history JSONL file") { |f| options[:file] = f }
  opts.on("-t", "--type TYPE", "Filter by message type (user, system, bot)") { |t| options[:type] = t }
  opts.on("-s", "--sender NAME", "Filter by sender name") { |s| options[:sender] = s }
end.parse!

if options[:file]
  parser = ChatLogParser.new(options[:file])
  filtered_messages = parser.filter_messages(type: options[:type], sender: options[:sender])
  puts JSON.pretty_generate(filtered_messages)
else
  puts "Error: Please provide a JSONL file using -f option."
end

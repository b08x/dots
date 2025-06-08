#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'table_tennis'

Dir.chdir Dir.home

# Extract gem names from a Gemfile
GEMFILE_PATH = `gum file --file --directory`.strip

# NLP-related keywords for filtering
NLP_KEYWORDS = [
  'natural language', 'nlp', 'text processing', 'linguistics', 'tokenize',
  'sentiment', 'language model', 'text analysis', 'parsing', 'grammar',
  'syntax', 'semantic', 'corpus', 'stemming', 'lemmatization', 'classification',
  'text mining', 'language detection', 'speech', 'translation', 'chatbot',
  'machine learning', 'ai', 'artificial intelligence', 'neural', 'deep learning'
].freeze

# Extract gem names from the Gemfile
def extract_gem_names(path)
  gems = []
  File.readlines(path).each do |line|
    line.strip!
    next if line.start_with?('#') || line.empty?

    gems << Regexp.last_match(1) if line =~ /^gem ['"]([^'"]+)['"]/
  end
  gems
end

# Fetch gem metadata from RubyGems API
def fetch_gem_info(gem_name)
  url = URI("https://rubygems.org/api/v1/gems/#{gem_name}.json")
  response = Net::HTTP.get_response(url)
  return nil unless response.is_a?(Net::HTTPSuccess)

  JSON.parse(response.body)
rescue StandardError => e
  puts "Error fetching info for #{gem_name}: #{e.message}"
  nil
end

# Check if a gem is NLP-related
def nlp_related?(gem_name, description)
  text_to_check = "#{gem_name} #{description}".downcase
  NLP_KEYWORDS.any? { |keyword| text_to_check.include?(keyword.downcase) }
end

# Truncate description to fit table
def truncate_description(description, max_length = 80)
  return 'N/A' if description.nil? || description.empty?

  description.length > max_length ? "#{description[0...max_length]}..." : description
end

# Main routine
puts 'Fetching gem information...'
gem_names = extract_gem_names(GEMFILE_PATH)

rows = gem_names.map.with_index do |gem_name, index|
  print "\rProcessing gem #{index + 1}/#{gem_names.length}: #{gem_name}"

  info = fetch_gem_info(gem_name)
  next unless info

  description = info['info'] || info['description'] || ''
  repo_url = info['source_code_uri'] || info['homepage_uri'] || 'N/A'

  {
    gem: gem_name,
    description: truncate_description(description),
    repository: repo_url,
    nlp_related: nlp_related?(gem_name, description)
  }
end.compact

puts "\n\n"

# Ask user for filter preference
puts 'Display options:'
puts '1. All gems'
puts '2. Only NLP-related gems'
print 'Choose an option (1 or 2): '
choice = gets.chomp

# Apply filter based on user choice
filtered_rows = case choice
                when '2'
                  nlp_gems = rows.select { |row| row[:nlp_related] }
                  if nlp_gems.empty?
                    puts 'No NLP-related gems found in the Gemfile.'
                    exit
                  end
                  nlp_gems
                else
                  rows
                end

# Remove the nlp_related field from display
display_rows = filtered_rows.map do |row|
  {
    gem: row[:gem],
    description: row[:description],
    repository: row[:repository]
  }
end

# Display the table
title = choice == '2' ? 'NLP-Related Gems' : 'All Gems from Gemfile'
options = {
  title: title,
  columns: %i[gem description repository],
  zebra: true,
  row_numbers: true
}

puts TableTennis.new(display_rows, options)

# # Summary
# total_gems = rows.length
# nlp_gems_count = rows.count { |row| row[:nlp_related] }
# puts "\nSummary:"
# puts "Total gems: #{total_gems}"
# puts "NLP-related gems: #{nlp_gems_count}"
# puts "Non-NLP gems: #{total_gems - nlp_gems_count}"

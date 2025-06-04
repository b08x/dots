#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'table_tennis'

Dir.chdir Dir.home
# Extract gem names from a Gemfile
GEMFILE_PATH = `gum file --file --directory`.strip

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
end

# Main routine
gem_names = extract_gem_names(GEMFILE_PATH)

rows = gem_names.map do |gem_name|
  info = fetch_gem_info(gem_name)
  next unless info

  repo_url = info['source_code_uri'] || info['homepage_uri'] || 'N/A'
  { gem: gem_name, repository: repo_url }
end.compact

# Display the table
options = {
  title: 'Gem to GitHub Repository Mapping',
  columns: %i[gem repository],
  zebra: true,
  row_numbers: true
}

puts TableTennis.new(rows, options)

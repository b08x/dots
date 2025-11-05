#!/usr/bin/env ruby
# frozen_string_literal: true

require 'uri'
require 'net/http'
require 'json'
require 'tty-markdown' # <-- Added for formatted output

# --- HTTP Request Setup (Unchanged) ---
url = URI('http://dify.syncopated.net/v1/datasets/c61cc957-5b46-4cca-a1b6-7e83f1391e0a/retrieve')

http = Net::HTTP.new(url.host, url.port)
request = Net::HTTP::Post.new(url)
request['Authorization'] = 'Bearer dataset-au1XxCnSwE29zzK8XBzMct8Z'
request['Content-Type'] = 'application/json'

request_body = {
  "query": 'ruby class',
  "retrieval_model": {
    "search_method": 'hybrid_search',
    "reranking_enable": false,
    "reranking_mode": {
      "reranking_provider_name": '<string>',
      "reranking_model_name": '<string>'
    },
    "top_k": 6,
    "score_threshold_enabled": false,
    "score_threshold": 123,
    "weights": 0.6
  }
}

request.body = request_body.to_json

# --- Execute Request ---
response = http.request(request)

# --- Parse and Display Logic (Unchanged) ---

# 1. Handle non-successful HTTP responses
unless response.is_a?(Net::HTTPSuccess)
  puts "HTTP Request failed: #{response.code} #{response.message}"
  puts '--- Response Body ---'
  puts response.body
  exit 1
end

# 2. Parse the JSON body
begin
  data = JSON.parse(response.read_body)
rescue JSON::ParserError => e
  puts 'Error: Failed to parse JSON response.'
  puts e.message
  puts '--- Raw Response Body ---'
  puts response.read_body
  exit 1
end

# 3. Check for the expected 'records' array
unless data['records']&.is_a?(Array)
  puts "Error: JSON response does not contain a 'records' array."
  puts '--- Full JSON Response ---'
  puts data
  exit
end

# 4. Display the query
query_content = data.dig('query', 'content') || request_body[:query]
puts TTY::Markdown.parse("# 📚 Dify Results for: `#{query_content}`")

if data['records'].empty?
  puts 'No records found.'
  exit
end

# 5. Iterate over each record and print its content as Markdown
data['records'].each_with_index do |record, index|
  # Extract relevant metadata
  score = record['score']
  segment = record['segment']
  content = segment['content']
  doc_name = segment.dig('document', 'name') || 'Unknown Document'

  # Format the score to 4 decimal places, handling nil
  formatted_score = score ? format('%.4f', score) : 'N/A'

  # Build a markdown string for this chunk
  markdown_chunk = <<~MD
    ---
    ## 🎯 Result #{index + 1} (Score: #{formatted_score})

    **Source:** `#{doc_name}`

    #{content}
  MD

  # 6. Print the formatted markdown to the console
  #
  # --- START: MODIFIED SECTION ---
  #
  # We wrap this in a rescue block because tty-markdown can crash on
  # complex Markdown (like tables with multiple images).
  # We also pass `width: 200` to give the wrapper more space,
  # which makes it less likely to fail.
  begin
    puts TTY::Markdown.parse(markdown_chunk, width: 200)
  rescue StandardError => e
    # Fallback: If tty-markdown fails, print the raw markdown chunk.
    puts "--- TTY-MARKDOWN FAILED (Error: #{e.message}) ---"
    puts '--- Printing Raw Markdown ---'
    puts markdown_chunk
  end
  #
  # --- END: MODIFIED SECTION ---
  #
end

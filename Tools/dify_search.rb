#!/usr/bin/env ruby
# frozen_string_literal: true

# --- Dependencies ---
# Make sure to run: gem install tty-prompt
require 'uri'
require 'net/http'
require 'json'
require 'tty-prompt'

# --- Main Application Module ---
module DifySearch
  # --- Configuration ---
  # Stores constants for easy modification
  module Config
    BASE_URL = 'http://dify.syncopated.net/v1'
    # NOTE: Store API keys securely, e.g., in environment variables
    # This key is from your provided scripts.
    API_KEY = 'Bearer dataset-au1XxCnSwE29zzK8XBzMct8Z'
    DATASETS_JSON_FILE = 'datasets.json'

    # Keys to keep when fetching datasets
    DATASET_KEYS_TO_KEEP = %w[
      id
      name
      description
      embedding_model
      embedding_model_provider
      retrieval_model_dict
      top_k
    ].freeze
  end

  # --- DatasetManager ---
  # Handles fetching, caching, and selecting datasets
  class DatasetManager
    def initialize
      @prompt = TTY::Prompt.new
      @datasets_file = Config::DATASETS_JSON_FILE
    end

    # Public entry point: ensures JSON exists, then prompts for selection
    def prompt_for_selection
      ensure_datasets_exist
      datasets = load_datasets
      select_datasets(datasets)
    end

    private

    # 1. Check for datasets.json, fetch if it's missing
    def ensure_datasets_exist
      return if File.exist?(@datasets_file)

      @prompt.warn("'#{@datasets_file}' not found. Fetching from Dify...")
      fetch_datasets
    rescue StandardError => e
      @prompt.error("Failed to fetch datasets: #{e.message}")
      exit 1
    end

    # 2. Fetch dataset list from API
    def fetch_datasets
      url = URI("#{Config::BASE_URL}/datasets?limit=40&include_all=true")
      http = Net::HTTP.new(url.host, url.port)
      request = Net::HTTP::Get.new(url)
      request['Authorization'] = Config::API_KEY

      response = http.request(request)
      raise "HTTP Error: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      full_data = JSON.parse(response.read_body)
      raise "Expected 'data' key in API response" unless full_data.key?('data')

      # Filter to only the keys you specified
      filtered_datasets = full_data['data'].map do |dataset|
        dataset.slice(*Config::DATASET_KEYS_TO_KEEP)
      end

      # Save to local cache file
      File.write(@datasets_file, JSON.pretty_generate(filtered_datasets))
      @prompt.ok("Successfully fetched and saved #{filtered_datasets.count} datasets.")
    end

    # 3. Load dataset info from local JSON
    def load_datasets
      file_content = File.read(@datasets_file)
      JSON.parse(file_content)
    rescue JSON::ParserError => e
      @prompt.error("Error parsing '#{@datasets_file}': #{e.message}")
      @prompt.warn("Try deleting '#{@datasets_file}' and re-running.")
      exit 1
    rescue StandardError => e
      @prompt.error("Error reading '#{@datasets_file}': #{e.message}")
      exit 1
    end

    # 4. Use tty-prompt to show multi-select menu
    def select_datasets(datasets)
      choices = datasets.map do |ds|
        { name: ds['name'], value: ds['id'] } # {name: "Display", value: "return_id"}
      end

      if choices.empty?
        @prompt.warn("No datasets found in '#{@datasets_file}'.")
        return []
      end

      @prompt.multi_select(
        'Which datasets would you like to search? (SPACE to select, ENTER to confirm)',
        choices,
        per_page: 10,
        cycle: true
      )
    end
  end

  # --- Querier ---
  # Executes a search query against a single dataset
  class Querier
    def initialize(dataset_id, query)
      @dataset_id = dataset_id
      @query = query
      @url = URI("#{Config::BASE_URL}/datasets/#{@dataset_id}/retrieve")
    end

    # Public entry point: runs the query and returns the parsed JSON
    def run
      http = Net::HTTP.new(@url.host, @url.port)
      request = build_request
      response = http.request(request)
      parse_response(response)
    rescue StandardError => e
      # Catch network errors, etc.
      { error: 'Failed to execute query', message: e.message }.to_json
    end

    private

    def build_request
      request = Net::HTTP::Post.new(@url)
      request['Authorization'] = Config::API_KEY
      request['Content-Type'] = 'application/json'

      # Use the request body from your script, inserting the dynamic query
      request_body = {
        "query": @query,
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
      request
    end

    # This is the parsing logic from your `retrieve_json...` script
    def parse_response(response)
      unless response.is_a?(Net::HTTPSuccess)
        return {
          error: 'HTTP Request failed',
          code: response.code,
          message: response.message
        }.to_json
      end

      data = JSON.parse(response.read_body)

      unless data['records']&.is_a?(Array)
        return {
          error: "JSON response does not contain a 'records' array",
          response_preview: data.to_s[0..200]
        }.to_json
      end

      # Build the clean output
      query_content = data.dig('query', 'content') || @query
      output_json = {
        query: query_content,
        dataset_id: @dataset_id, # Add context for which dataset this was
        results: []
      }

      data['records'].each do |record|
        output_json[:results] << {
          source: record.dig('segment', 'document', 'name') || 'Unknown Document',
          score: record['score'],
          content: record.dig('segment', 'content')
        }
      end

      # Return the final object as a JSON string
      output_json.to_json
    rescue JSON::ParserError => e
      { error: 'Failed to parse JSON response', message: e.message }.to_json
    end
  end

  # --- CLI ---
  # Orchestrates the application flow
  class CLI
    def initialize
      @prompt = TTY::Prompt.new
    end

    def run
      # 1. Get dataset selections
      manager = DatasetManager.new
      selected_ids = manager.prompt_for_selection

      if selected_ids.empty?
        @prompt.ok('No datasets selected. Exiting.')
        exit
      end

      # 2. Get search query
      query = @prompt.ask('Enter your search query:') do |q|
        q.required true
        q.modify :strip
      end

      if query.nil? || query.empty?
        @prompt.error('No query provided. Exiting.')
        exit
      end

      # 3. Run query for each dataset and print results
      @prompt.ok("Querying #{selected_ids.count} dataset(s) for '#{query}'...")
      puts "\n" # Add a newline for cleaner output

      selected_ids.each do |id|
        @prompt.say("--- Results for Dataset: #{id} ---")

        # Create a new querier for each ID and run it
        querier = Querier.new(id, query)
        result_json_string = querier.run

        # Pretty-print the JSON for readability
        puts JSON.pretty_generate(JSON.parse(result_json_string))
        puts "\n" # Add space between results
      end
    end
  end
end

# --- Run the Application ---
# This ensures the code only runs when the file is executed directly
DifySearch::CLI.new.run if $PROGRAM_NAME == __FILE__

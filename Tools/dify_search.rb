#!/usr/bin/env ruby
# frozen_string_literal: true

# --- Dependencies ---
# Make sure to run: gem install tty-prompt informers
# - tty-prompt: Interactive command-line prompts
# - informers: Transformer models for re-ranking (optional, only needed with --rerank flag)
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

    # Reranking configuration
    RERANKING_MODEL = 'BAAI/bge-reranker-base'
    RERANKING_MAX_RESULTS = 20 # Maximum number of results to rerank
    RERANKING_ENABLED_DEFAULT = false # Default state for reranking
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

  # --- Reranker ---
  # Re-ranks search results using a cross-encoder model
  class Reranker
    def initialize(query, results, max_results: Config::RERANKING_MAX_RESULTS)
      @query = query
      @results = results
      @max_results = max_results
      @prompt = TTY::Prompt.new
      require_informers_gem
    end

    # Public entry point: re-ranks results and returns them
    def run
      # Limit number of results if needed
      limited_results = @results.first(@max_results)

      # Extract content for reranking
      contents = extract_contents(limited_results)

      if contents.empty?
        @prompt.warn('No content found for reranking. Returning original results.')
        return @results
      end

      # Initialize reranking pipeline
      reranker = Informers.pipeline('reranking', Config::RERANKING_MODEL)

      # Get reranked scores
      reranked_data = reranker.(@query, contents)

      # Apply reranking scores and return
      apply_reranking(limited_results, reranked_data)
    rescue StandardError => e
      @prompt.error("Reranking failed: #{e.message}")
      @prompt.warn('Returning original results.')
      @results
    end

    private

    # Lazy-load the informers gem
    def require_informers_gem
      require 'informers'
    rescue LoadError => e
      @prompt.error('The informers gem is required for re-ranking.')
      @prompt.error("Please install it with: gem install informers")
      @prompt.error("Error: #{e.message}")
      exit 1
    end

    # Extract content strings from results array
    def extract_contents(results)
      results.map { |r| r[:content] || r['content'] }.compact
    end

    # Merge reranking scores back into results
    def apply_reranking(original_results, reranked_data)
      # reranked_data is an array of hashes with :doc_id and :score
      reranked_results = reranked_data.map.with_index do |rerank_info, position|
        doc_id = rerank_info[:doc_id]
        original_result = original_results[doc_id]

        # Create new result with both original and rerank scores
        {
          source: original_result[:source] || original_result['source'],
          original_score: original_result[:score] || original_result['score'],
          rerank_score: rerank_info[:score],
          rerank_position: position + 1,
          content: original_result[:content] || original_result['content']
        }
      end

      reranked_results
    end
  end

  # --- CLI ---
  # Orchestrates the application flow
  class CLI
    def initialize
      @prompt = TTY::Prompt.new
      @options = parse_arguments
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
      rerank_status = @options[:rerank] ? ' (with re-ranking)' : ''
      @prompt.ok("Querying #{selected_ids.count} dataset(s) for '#{query}'...#{rerank_status}")
      puts "\n" # Add a newline for cleaner output

      selected_ids.each do |id|
        @prompt.say("--- Results for Dataset: #{id} ---")

        # Create a new querier for each ID and run it
        querier = Querier.new(id, query)
        result_json_string = querier.run

        # Parse the JSON results
        result_data = JSON.parse(result_json_string)

        # Apply re-ranking if enabled
        if @options[:rerank] && result_data['results']&.is_a?(Array) && !result_data['results'].empty?
          @prompt.say("Re-ranking results (limit: #{@options[:rerank_limit]})...")

          # Convert string keys to symbols for Reranker
          results_with_symbols = result_data['results'].map do |r|
            {
              source: r['source'],
              score: r['score'],
              content: r['content']
            }
          end

          # Apply reranking
          reranker = Reranker.new(query, results_with_symbols, max_results: @options[:rerank_limit])
          reranked_results = reranker.run

          # Update result data with reranked results
          result_data['results'] = reranked_results
          result_data['reranked'] = true
          result_data['rerank_model'] = Config::RERANKING_MODEL
        end

        # Pretty-print the JSON for readability
        puts JSON.pretty_generate(result_data)
        puts "\n" # Add space between results
      end
    end

    private

    # Parse command-line arguments
    def parse_arguments
      options = {
        rerank: Config::RERANKING_ENABLED_DEFAULT,
        rerank_limit: Config::RERANKING_MAX_RESULTS
      }

      # Simple argument parsing for --rerank and --rerank-limit
      ARGV.each_with_index do |arg, idx|
        case arg
        when '--rerank', '-r'
          options[:rerank] = true
          ARGV.delete_at(idx)
        when '--rerank-limit'
          if ARGV[idx + 1] && ARGV[idx + 1].match?(/^\d+$/)
            options[:rerank_limit] = ARGV[idx + 1].to_i
            ARGV.delete_at(idx + 1)
            ARGV.delete_at(idx)
          else
            @prompt.error('--rerank-limit requires a numeric argument')
            exit 1
          end
        when '--help', '-h'
          print_help
          exit 0
        end
      end

      options
    end

    # Display help information
    def print_help
      puts <<~HELP
        Usage: #{$PROGRAM_NAME} [OPTIONS]

        Search datasets and optionally re-rank results using a cross-encoder model.

        Options:
          -r, --rerank              Enable re-ranking of search results
          --rerank-limit N          Maximum number of results to re-rank (default: #{Config::RERANKING_MAX_RESULTS})
          -h, --help                Show this help message

        Examples:
          #{$PROGRAM_NAME}                    # Normal search without re-ranking
          #{$PROGRAM_NAME} --rerank           # Search with re-ranking enabled
          #{$PROGRAM_NAME} --rerank --rerank-limit 10   # Re-rank top 10 results only
      HELP
    end
  end
end

# --- Run the Application ---
# This ensures the code only runs when the file is executed directly
DifySearch::CLI.new.run if $PROGRAM_NAME == __FILE__

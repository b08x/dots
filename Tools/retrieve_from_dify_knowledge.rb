#!/usr/bin/env ruby
# frozen_string_literal: true

# !/usr/bin/env ruby
# frozen_string_literal: true

require 'uri'
require 'net/http'
require 'json' # Added library to handle JSON cleanly

url = URI('http://dify.syncopated.net/v1/datasets/c61cc957-5b46-4cca-a1b6-7e83f1391e0a/retrieve')

http = Net::HTTP.new(url.host, url.port)
# If using HTTPS, you would need to add:
# http.use_ssl = true

request = Net::HTTP::Post.new(url)
request['Authorization'] = 'Bearer dataset-au1XxCnSwE29zzK8XBzMct8Z'
request['Content-Type'] = 'application/json'

# Define the body as a Ruby Hash and convert it to JSON
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

response = http.request(request)
puts response.read_body

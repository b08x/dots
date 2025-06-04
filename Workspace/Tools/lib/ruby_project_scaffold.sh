#!/usr/bin/env bash

# Ruby Project Scaffolding Script
# This script creates a new Ruby project with a structure similar to flowbots_v1
# Usage: ./ruby_project_scaffold.sh PROJECT_NAME [AUTHOR_NAME] [AUTHOR_EMAIL]

set -e

# Default values
CURRENT_YEAR=$(date +%Y)
AUTHOR_NAME=${2:-"Your Name"}
AUTHOR_EMAIL=${3:-"your.email@example.com"}

# Check if project name is provided
if [ -z "$1" ]; then
  echo "Error: Project name is required"
  echo "Usage: $0 PROJECT_NAME [AUTHOR_NAME] [AUTHOR_EMAIL]"
  exit 1
fi

PROJECT_NAME=$1
PROJECT_PATH=$(pwd)/$PROJECT_NAME
LIB_NAME=$PROJECT_NAME
CLASS_NAME=$(echo $PROJECT_NAME | sed -r 's/(^|_)([a-z])/\U\2/g') # Convert snake_case to CamelCase

echo "Creating Ruby project: $PROJECT_NAME"
echo "Location: $PROJECT_PATH"

# Create root directory
mkdir -p "$PROJECT_PATH"
cd "$PROJECT_PATH"

# Create standard directories
mkdir -p lib/$LIB_NAME
mkdir -p bin
mkdir -p exe
mkdir -p test/{fixtures,support}
mkdir -p docs
mkdir -p examples
mkdir -p scripts
mkdir -p assets
mkdir -p log
mkdir -p models

# Create main lib file
cat > "lib/$LIB_NAME.rb" << EOF
# frozen_string_literal: true

require_relative "$LIB_NAME/version"

module $CLASS_NAME
  class Error < StandardError; end
  
  # Your code goes here...
end
EOF

# Create version file
mkdir -p "lib/$LIB_NAME"
cat > "lib/$LIB_NAME/version.rb" << EOF
# frozen_string_literal: true

module $CLASS_NAME
  VERSION = "0.1.0"
end
EOF

# Create executable file
mkdir -p exe
cat > "exe/$LIB_NAME" << EOF
#!/usr/bin/env ruby
# frozen_string_literal: true

require "$LIB_NAME"

# Add your CLI code here
EOF
chmod +x "exe/$LIB_NAME"

# Create Gemfile
cat > Gemfile << EOF
# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem 'gli', '~> 2.21'
gem 'tty-prompt', '~> 0.23'
gem 'tty-box', '~> 0.7'
gem 'tty-markdown', '~> 0.7'
gem 'tty-table', '~> 0.12'
gem 'tty-editor', '~> 0.7'
gem 'tty-config', '~> 0.5'
gem 'front_matter_parser', '~> 1.0'
gem 'dotenv'

group :development do
  # Development-only gems
  gem 'listen', require: false
  gem 'rubocop', require: false
  gem 'rubocop-minitest'
  gem 'rubocop-packaging'
  gem 'rubocop-performance'
  gem 'rubocop-rake'
  gem 'rubocop-rspec'
  gem 'rubocop-shopify'
  gem 'rubocop-thread_safety'
  gem 'ruby-lsp'
  gem 'solargraph'
  gem 'webrick'
end
EOF

# Create gemspec file
cat > "$LIB_NAME.gemspec" << EOF
# frozen_string_literal: true

require_relative "lib/$LIB_NAME/version"

Gem::Specification.new do |spec|
  spec.name = "$LIB_NAME"
  spec.version = $CLASS_NAME::VERSION
  spec.authors = ["$AUTHOR_NAME"]
  spec.email = ["$AUTHOR_EMAIL"]

  spec.summary = "Write a short summary"
  spec.description = "Write a longer description"
  spec.homepage = "https://github.com/username/$LIB_NAME"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "\#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    \`git ls-files -z\`.split("\\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
EOF

# Create Rakefile
cat > Rakefile << EOF
# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"
require "rubocop/rake_task"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

RuboCop::RakeTask.new

task default: %i[test rubocop]
EOF

# Create test helper
cat > "test/test_helper.rb" << EOF
# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "$LIB_NAME"

require "minitest/autorun"
EOF

# Create a basic test file
cat > "test/${LIB_NAME}_test.rb" << EOF
# frozen_string_literal: true

require "test_helper"

class ${CLASS_NAME}Test < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::${CLASS_NAME}::VERSION
  end

  def test_it_does_something_useful
    assert true
  end
end
EOF

# Create README.md
cat > README.md << EOF
# $CLASS_NAME

Welcome to your new gem! In this directory, you'll find the files you need to be able to package up your Ruby library into a gem. Put your Ruby code in the file \`lib/$LIB_NAME\`. To experiment with that code, run \`bin/console\` for an interactive prompt.

## Installation

Install the gem and add to the application's Gemfile by executing:

    \$ bundle add $LIB_NAME

If bundler is not being used to manage dependencies, install the gem by executing:

    \$ gem install $LIB_NAME

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run \`bin/setup\` to install dependencies. Then, run \`rake test\` to run the tests. You can also run \`bin/console\` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run \`bundle exec rake install\`. To release a new version, update the version number in \`version.rb\`, and then run \`bundle exec rake release\`, which will create a git tag for the version, push git commits and the created tag, and push the \`.gem\` file to [rubygems.org](https://rubygems.org).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
EOF

# Create LICENSE file
cat > LICENSE << EOF
MIT License

Copyright (c) $CURRENT_YEAR $AUTHOR_NAME

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF

# Create CHANGELOG.md
cat > CHANGELOG.md << EOF
# Changelog

## [0.1.0] - $(date +%Y-%m-%d)

- Initial release
EOF

# Create .gitignore
cat > .gitignore << EOF
/.bundle/
/.yardoc
/_yardoc/
/coverage/
/doc/
/pkg/
/spec/reports/
/tmp/
.ruby-version
Gemfile.lock
EOF

# Create bin/console
mkdir -p bin
cat > bin/console << EOF
#!/usr/bin/env ruby
require "bundler/setup"
require_relative "../lib/${LIB_NAME}"



require "pry"
Pry.start
EOF
chmod +x bin/console

# Create bin/setup
cat > bin/setup << EOF
#!/usr/bin/env bash
set -euo pipefail
IFS=\$'\n\t'
set -vx

echo "put project dependencies here";sleep 1

bundle install
EOF
chmod +x bin/setup

# Create Docker-related files
cat > Dockerfile << EOF
FROM ruby:3.2-alpine

WORKDIR /app

RUN apk add --no-cache build-base git

COPY Gemfile* *.gemspec ./
COPY lib/$LIB_NAME/version.rb lib/$LIB_NAME/version.rb

RUN bundle install

COPY . .

CMD ["bin/console"]
EOF

cat > docker-compose.yml << EOF
version: '3'

services:
  app:
    build: .
    volumes:
      - .:/app
    command: bin/console
EOF

echo "Project $PROJECT_NAME has been created successfully at $PROJECT_PATH"
echo "Next steps:"
echo "  1. cd $PROJECT_NAME"
echo "  2. git init"
echo "  3. bundle install"
echo "  4. Start coding!"
# Sonic Pi init file
# Code in here will be evaluated on launch.

sonichome = File.expand_path "~/.sonic-pi"

load_snippets sonichome + "/snippets", true

# Run all files in the helpers subdirectory
Dir.glob(sonichome + "/helpers/**/*.{spi,rb}").each do |path|
  run_file path
end

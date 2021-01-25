# Sonic Pi init file
# Code in here will be evaluated on launch.

sonic_home = File.join(ENV['HOME'], ".sonic-pi")

load_snippets sonic_home + "/snippets", true

# Run all files in the helpers subdirectory
Dir.glob(mypath + "/helpers/**/*.{spi,rb}").each do |path|
  run_file path
end

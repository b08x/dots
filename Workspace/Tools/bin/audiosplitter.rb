#!/usr/bin/env ruby
# frozen_string_literal: true

require 'open3'
require 'fileutils'
require 'optparse'

# Default values
options = {
  silence_duration: 0.1,
  overlap_duration: 0.0,
  output_format: "%{basename}-%{index}%{ext}",
}

# Parse command-line arguments
OptionParser.new do |opts|
  opts.banner = "Usage: audiosplitter.rb [options] <silence_file> <audio_file>"

  opts.on("-d", "--duration DURATION", Float, "Silence detection duration in seconds (default: #{options[:silence_duration]})") do |d|
    options[:silence_duration] = d
  end

  opts.on("-o", "--overlap DURATION", Float, "Overlap duration in seconds (default: #{options[:overlap_duration]})") do |o|
    options[:overlap_duration] = o
  end
  
  opts.on("-f", "--format FORMAT", String, "Output file format (default: #{options[:output_format]})") do |f|
    options[:output_format] = f
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

# Check if input filename is provided
if ARGV.length < 2
  puts "Error: Audio file and silence file must be provided."
  puts "Run 'audiosplitter.rb --help' for more information."
  exit 1
end

filename = ARGV[1]
ext = File.extname(filename)
basename = File.basename(filename, ext)

# Run the ffmpeg command to detect silence and parse the output
output, _error, _status = Open3.capture3(
  "ffmpeg -i #{filename} -af silencedetect=d=#{options[:silence_duration]} -f null -"
)

# Check for ffmpeg errors
unless _status.success?
  puts "Error: ffmpeg failed with the following output:"
  puts _error
  exit 1
end
timechunks = output.scan(/silence_end: ([\d\.]+)/).map { |match| match[0].to_f }
timechunks = timechunks.map {|x| x.round(3)}
# Convert the timechunks into HH:MM:SS format
formatted_timechunks = timechunks.map do |chunk|
  seconds = chunk.to_i
  hours = seconds / (60 * 60)
  seconds %= (60 * 60)
  minutes = seconds / 60
  seconds %= 60
  sprintf("%02d:%02d:%02d", hours, minutes, seconds)
end

# Process the chunks
initcmd = "ffmpeg -nostdin -hide_banner -loglevel error -i #{filename}"
formatted_timechunks.each_with_index do |chunk, index|
  start_time = if index.zero?
                 0.0
               else
                 timechunks[index - 1] - options[:overlap_duration]
               end
  
  start_time = [start_time, 0.0].max

  formatted_start_time = if start_time == 0.0 then '00:00:00' else  sprintf("%02d:%02d:%02d", (start_time.to_i) / 3600, ((start_time.to_i)% 3600) / 60, (start_time.to_i) % 60) end

  output_filename = options[:output_format]
                    .gsub("%{basename}", basename)
                    .gsub("%{index}", index.to_s)
                    .gsub("%{ext}", ext)
  

  initcmd += " -ss #{formatted_start_time} -to #{chunk} -c copy \"#{output_filename}\""
end

# Run the final ffmpeg command
system(initcmd)

# Example usage:

# This will use the default silence detection duration (0.1 seconds) and no overlap.
# ./audiosplitter.rb silence.txt MyLongAudio.mp3

# This will use a silence detection duration of 0.5 seconds.
# ./audiosplitter.rb -d 0.5 silence.txt MyLongAudio.mp3

# This will create segments with a 2.5-second overlap.
# ./audiosplitter.rb -o 2.5 silence.txt MyLongAudio.mp3

# This sets the silence duration to 0.2 seconds and the overlap to 1.0 seconds.
# ./audiosplitter.rb -d 0.2 -o 1.0 silence.txt MyLongAudio.mp3

# This will generate files named like MyLongAudio_part0.mp3, MyLongAudio_part1.mp3, etc.
# ./audiosplitter.rb -f "%{basename}_part%{index}%{ext}" silence.txt MyLongAudio.mp3

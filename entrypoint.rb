#!/usr/bin/env ruby
require 'fileutils'
require 'yaml'

# Set environment
ENV_FILE_REGEX = /^\s*ENV_FILE(?:_(?<name>[_A-Z0-9]+))?=(?<path>.+\.env)\s*$/
ENVIRONMENT_REGEX = /^\s*(?<name>[^#][^=]+)[=](?<value>.+)$/

# Export environment variables from file if provided
ENV.map { |k, v| ENV_FILE_REGEX.match("#{k}=#{v}") }.compact.each do |match|
  break unless File.exist?(match[:path])
  env_file = File.open(match[:path]).read
  env_file.gsub!(/\r\n?/, "\n")
  env_file.each_line do |env_line|
    match = ENVIRONMENT_REGEX.match(env_line)
    ENV[match[:name]] = match[:value] if match
  end
end

# Create the irb configuration file
File.open("#{ENV['HOME']}/.irbrc", 'w') { |f| f.write(<<EOF) } if ENV['HOME']
  IRB.conf[:SAVE_HISTORY] = 1000
  IRB.conf[:HISTORY_FILE] = "\#{ENV['HOME']}/.irb_history"
EOF

# Remove the bundle configuration if it exists
FileUtils.rm_f("#{ENV['HOME']}/.bundle/config")

# Execute an application specific entrypoint if present
docker_entrypoint = Dir["#{Dir.pwd}/docker-entrypoint*", "#{Dir.pwd}/entrypoint*"].select { |f| File.executable?(f) }.first
ARGV.unshift(docker_entrypoint) if docker_entrypoint && File.exist?(docker_entrypoint)

# Execute the passed in command if provided
exec(*ARGV) unless ARGV.empty?

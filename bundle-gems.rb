#!/usr/bin/env ruby
require 'aws-sdk'
require 'digest'
require 'fileutils'

exit 0 unless ENV['BUNDLE_GEMS'] == 'true'

# Set variables
cache_gzip_filename = 'bundled-gems.tar.gz'
local_cache_gzip_file = File.join('/tmp', cache_gzip_filename)
s3_cache_gzip_file = nil

define_method :system do |*args|
  Kernel.system *args
  exit $?.exitstatus unless $?.success?
end

def compute_directory_hash(path)
  Dir.glob("#{path}/**/*").map do |name|
    [name, File.mtime(name)].to_s
  end.inject(Digest::SHA512.new) do |digest, x|
    digest.update(x)
  end.to_s
end

# Make sure environment is properly set for cache retrieval and uploadi
if ENV['CACHE_BUNDLED_GEMS'] == 'true'
  exit 1 && STDERR.puts('Missing environment variable AWS_ACCESS_KEY_ID') unless ENV['AWS_ACCESS_KEY_ID']
  exit 1 && STDERR.puts('Missing environment variable AWS_SECRET_ACCESS_KEY') unless ENV['AWS_SECRET_ACCESS_KEY']
  exit 1 && STDERR.puts('Missing environment variable AWS_REGION') unless ENV['AWS_REGION']
  exit 1 && STDERR.puts('Missing environment variable AWS_S3_BUCKET_NAME') unless ENV['AWS_S3_BUCKET_NAME']

  # Initialize S3 resources
  puts 'Initializing connection to build cache...'
  s3 = Aws::S3::Resource.new(
    access_key_id: ENV['AWS_ACCESS_KEY_ID'],
    secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
    region: ENV['AWS_REGION']
  )
  bucket = s3.bucket(ENV['AWS_S3_BUCKET_NAME'])
  s3_cache_gzip_file = bucket.object(cache_gzip_filename)
end

# Ensure we have a local directory
FileUtils.mkdir_p(ENV['BUNDLE_PATH'])

# Try to download previously remote cached tar
if ENV['CACHE_BUNDLED_GEMS'] == 'true'
  puts 'Checking build cache for bundled gems...'
  if s3_cache_gzip_file.exists?
    puts 'Retrieving bundled gems from build cache...'
    s3_cache_gzip_file.get(response_target: local_cache_gzip_file)
    puts 'Extracting bundled gems build cache...'
    Dir.chdir(ENV['BUNDLE_PATH']) do
      system "tar xzf #{local_cache_gzip_file}"
    end
    FileUtils.rm_f(local_cache_gzip_file)
  end
end

# Compute the bundled gems hash
puts 'Computing hash of bundled gems...'
local_directory_hash = compute_directory_hash(ENV['BUNDLE_PATH'])

# Bundle gems
puts 'Bundling ruby gems...'
system 'bundle install --without development test --deployment'
puts 'Cleaning unused bundled gems...'
system 'bundle clean'

# Update the remote cache tar if changed
if ENV['CACHE_BUNDLED_GEMS'] == 'true' && compute_directory_hash(ENV['BUNDLE_PATH']) != local_directory_hash
  puts 'Creating bundled gems build cache...'
  Dir.chdir(ENV['BUNDLE_PATH']) do
    system "tar czf #{local_cache_gzip_file} ."
  end
  puts 'Uploading bundled gems to build cache...'
  s3_cache_gzip_file.upload_file(local_cache_gzip_file)
  FileUtils.rm_f(local_cache_gzip_file)
end

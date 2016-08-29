#!/usr/bin/env ruby
require 'aws-sdk'
require 'digest'
require 'fileutils'

exit 0 unless ENV['COMPILE_ASSETS'] == 'true'

# Set variables
cache_gzip_filename = 'compiled-assets.tar.gz'
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
if ENV['CACHE_COMPILED_ASSETS'] == 'true'
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
end

# Iterate for each environment
ENV['RAILS_BUILD_ENVIRONMENTS'].split(',').each do |stage|
  # Ensure we have a local directory
  assets_directory = "./public/assets.#{stage}"
  FileUtils.mkdir_p(assets_directory)

  # Try to download previously remote cached tar
  if ENV['CACHE_COMPILED_ASSETS'] == 'true'
    puts "Checking build cache for #{stage} compiled assets..."
    s3_cache_gzip_file = bucket.object("#{stage}-#{cache_gzip_filename}")
    if s3_cache_gzip_file.exists?
      puts "Retrieving #{stage} compiled assets from build cache..."
      s3_cache_gzip_file.get(response_target: local_cache_gzip_file)
      puts "Extracting #{stage} compiled assets build cache..."
      Dir.chdir(assets_directory) do
        system "tar xzf #{local_cache_gzip_file}"
      end
      FileUtils.rm_f(local_cache_gzip_file)
    end
  end

  # Compute the compiled assets hash
  puts "Computing hash of #{stage} compiled assets..."
  local_directory_hash = compute_directory_hash(assets_directory)

  puts "Pre-compiling #{stage} assets..."
  FileUtils.mv(assets_directory, './public/assets')
  system ({ 'RAILS_ENV' => stage }), 'bundle exec rails assets:precompile'
  puts "Cleaning obsolete #{stage} compiled assets..."
  system ({ 'RAILS_ENV' => stage }), 'bundle exec rails assets:clean'
  FileUtils.mv('./public/assets', assets_directory)

  # Update the remote cache tar if changed
  if ENV['CACHE_COMPILED_ASSETS'] == 'true' && compute_directory_hash(assets_directory) != local_directory_hash
    puts "Creating #{stage} compiled assets build cache..."
    Dir.chdir(assets_directory) do
      system "tar czf #{local_cache_gzip_file} ."
    end
    puts "Uploading #{stage} compiled assets to build cache..."
    s3_cache_gzip_file = bucket.object("#{stage}-#{cache_gzip_filename}")
    s3_cache_gzip_file.upload_file(local_cache_gzip_file)
    FileUtils.rm_f(local_cache_gzip_file)
  end
end

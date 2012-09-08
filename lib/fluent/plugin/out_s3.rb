module Fluent


class S3Output < Fluent::TimeSlicedOutput
  Fluent::Plugin.register_output('s3', self)

  def initialize
    super
    require 'aws-sdk'
    require 'zlib'
    require 'time'
    require 'tempfile'
  end

  config_param :path, :string, :default => ""
  config_param :time_format, :string, :default => nil

  config_param :aws_key_id, :string
  config_param :aws_sec_key, :string
  config_param :s3_bucket, :string
  config_param :s3_endpoint, :string, :default => nil

  def configure(conf)
    super

    @timef = TimeFormatter.new(@time_format, @localtime)
  end

  def start
    super
    options = {
      :access_key_id     => @aws_key_id,
      :secret_access_key => @aws_sec_key
    }
    options[:s3_endpoint] = @s3_endpoint if @s3_endpoint
    @s3 = AWS::S3.new(options)
    @bucket = @s3.buckets[@s3_bucket]
  end

  def format(tag, time, record)
    time_str = @timef.format(time)

    rec_utf8 = Hash.new
    record.each { |key, value|
      rec_utf8.store(key, value.force_encoding("UTF-8"))
    }
    "#{time_str}\t#{tag}\t#{rec_utf8.to_json}\n"
  end

  def write(chunk)
    i = 0
    begin
      s3path = "#{@path}#{chunk.key}_#{i}.gz"
      i += 1
    end while @bucket.objects[s3path].exists?

    tmp = Tempfile.new("s3-")
    w = Zlib::GzipWriter.new(tmp)
    begin
      chunk.write_to(w)
      w.close
      @bucket.objects[s3path].write(Pathname.new(tmp.path))
    ensure
      w.close rescue nil
    end
  end
end


end


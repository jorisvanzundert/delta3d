require 'rubygems'
require 'sinatra'
require 'json/pure'
require 'delta3d'
require 'base64'
require 'openssl'
require 'uri'
require "sinatra/reloader" if development?

set :environment, :development

disable :raise_errors
disable :show_exceptions

class Delta3DController
  
  get '/status' do
    body Thread.main["thread_exceptions"].inspect
  end

  get '/doc' do
    erb :doc
  end
  
  get '/index' do
    erb :index
  end
  
  post '/process' do
    content_type 'text/html'
    params['delta_parameters']
    json_string = params['file'];
    json_string = params['file'][:tempfile].read if params['file'][:tempfile]
    parameters = params.reject { |key,value| key.eql?('file') }
    tmp_suffix = Time.now.strftime("%Y%m%d%H%M%S")
    thread = Thread.new(params['delta_parameters']) do |parameters|
      thread_id = "#{Thread.current.object_id}_#{tmp_suffix}"
      timeout = Thread.new { sleep(120); kill_thread( thread_id ) }
      Thread.current["thread_id"] = thread_id
      begin
        parameters = parameters.merge(parameters){ |key,old_val| old_val.eql?("") ? "0" : old_val }
        invalid_params = parameters.reject{ |param, value| Integer(value) rescue false }
        raise ArgumentError, "Invalid parameter(s) detected, please check: #{prettify(invalid_params)}" if invalid_params.length != 0
        parameters = parameters.inject({}){ |memo, (key,value)| memo[key.to_sym]=Integer(value); memo }
        delta3d = Delta3D.new( json_string )
        svgs = delta3d.plot( delta3d.calculate(parameters) )
        path = File.expand_path(File.dirname(__FILE__))
        svgs_tmp_file = File.new( "#{path}/tmp/#{thread_id}.tmp", "w" )
        svgs_tmp_file.write( svgs )
        svgs_tmp_file.close 
      rescue Exception => e
        # puts e.inspect
        # puts e.backtrace
        list_exception( thread_id, e )
        exit
      end
    end
    token = encrypt_token( "#{thread.object_id}_#{tmp_suffix}" )
    Thread.new{ garbage_disposal }
    body "#{token}"
  end
  
  post '/svg_available' do
    params["token"].nil? ? svgs_tmp_filename = "" : svgs_tmp_filename = decrypt_token( params["token"] ) 
    path = File.expand_path(File.dirname(__FILE__))
    available = ( File.exist?( "#{path}/tmp/#{svgs_tmp_filename}.tmp" ) ? true : false )
    if !Thread.main["thread_exceptions"].nil? && !Thread.main["thread_exceptions"][svgs_tmp_filename].nil?
      resp = Thread.main["thread_exceptions"][svgs_tmp_filename].message
    else
      resp = "#{available}"
    end
    body resp
  end
  
  post '/svg' do
    params["token"].nil? ? svgs_tmp_filename = "" : svgs_tmp_filename = decrypt_token( params["token"] ) 
    path = File.expand_path(File.dirname(__FILE__))
    svgs_tmp_filename = "#{path}/tmp/#{svgs_tmp_filename}.tmp"
    if File.exist?( svgs_tmp_filename )
      body File.read( svgs_tmp_filename )
    else
      halt 404, "SVG not found"
    end
  end

  error do
    puts "ouch ie ouch"
    "Something didn't went quite as expected - error: #{request.env['sinatra.error'].message}"
  end
  
  helpers do

    def inject_secret( mode )
      path = File.expand_path(File.dirname(__FILE__))
      secret_hash = JSON.load( File.new( "#{path}/secret.json", "r" ) )
      aes = OpenSSL::Cipher.new("AES-256-CFB")  
      aes.send( mode )
      aes.key = Base64.decode64( secret_hash["key"] )
      aes.iv = secret_hash["inivector"]
      aes
    end
      
    def encrypt_token( thread_id )
      aes = inject_secret( :encrypt )
      encrypted = aes.update( thread_id ) + aes.final
      token = Base64.encode64( encrypted )
      token
    end

    def decrypt_token( token )
      encrypted = Base64.decode64( token )
      aes = inject_secret( :decrypt )
      decrypted = aes.update( encrypted ) + aes.final
      decrypted
    end
    
    def list_exception( thread_id, excp )
      if Thread.main["thread_exceptions"].nil?
        Thread.main["thread_exceptions"]={ thread_id => excp }
      else
        Thread.main["thread_exceptions"][thread_id] = excp
      end
    end
    
    def kill_thread( thread_id )
      Thread.list.each do |thread| 
        if thread["thread_id"].eql?(thread_id)
          thread.kill
          list_exception( thread_id, StandardError.new( "Delta computation execution time out… Try to adjust parameters to realize a less intensive calculation." ) )
        end
      end
    end
    
    def garbage_disposal
      time_now = Time.now
      if !Thread.main["thread_exceptions"].nil?
        Thread.main["thread_exceptions"].each_key { |key|
          key_time = key[-14,14]
          exception_time = Time.mktime( key_time[0,4], key_time[4,2], key_time[6,2], key_time[8,2], key_time[10,2], key_time[12,2] )
          Thread.main["thread_exceptions"].delete(key) if (time_now - exception_time) > 120
        }
      end
      path = File.expand_path(File.dirname(__FILE__))
      Dir.entries("#{path}/tmp/").reject!{ |f| !f.split("/").last.end_with?(".tmp") }.each { |f|
        filename_time = f[-18,14]
        file_time = Time.mktime( filename_time[0,4], filename_time[4,2], filename_time[6,2], filename_time[8,2], filename_time[10,2], filename_time[12,2] )
        File.delete( File.join("#{path}/tmp/", f) ) if (time_now - file_time) > 120
      }
    end
    
    def prettify( invalid_params )
      message ="<div class=\"invalid_params_report\">"
      invalid_params.each do |key,value|
        param_name = key.gsub( /_/, " " )
        param_name = param_name.slice(0,1).capitalize + param_name.slice(1..-1)
        message << "<div class=\"invalid_param\">#{param_name}: \"#{value}\"</div>"
      end
      message << "</div>"
    end
    
  end

end
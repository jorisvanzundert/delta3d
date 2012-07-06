require 'rubygems'
require 'digest/sha2'
require 'base64'
require 'json/pure'

sha256 = Digest::SHA2.new(256)
secret_hash = { "inivector" => rand.to_s, "key" => Base64.encode64( sha256.digest( rand(36**8).to_s(36) ) ) }
path = File.expand_path(File.dirname(__FILE__))
secret_file = File.new( "secret.json", "w" )
secret_file.write( JSON.generate( secret_hash ) )
secret_file.close

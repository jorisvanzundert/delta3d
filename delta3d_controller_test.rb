require 'delta3d_controller.rb'
require 'test/unit'
require 'rack/test'

ENV['RACK_ENV'] = 'test'

class Delta3DControllerTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def test_doc
    get '/doc'
    assert last_response.ok?
    assert last_response.body =~ /delta3d_svg(.*)/
  end

  def test_not_json
    not_json_string = '{ "line": { "position": { "token": [ "lemma1", "lemma2", "lemma3" }'
    post '/delta3d_svg', 'json' => not_json_string
    assert last_response.body.include? "error: expected ',' or ']'"
  end

  def test_valid_json
    too_deep_json_string = '{ "line": { "position": { "token": { "todeep": [ "lemma1", "lemma2", "lemma3" ] } } } }'
    post '/delta3d_svg', 'json' => too_deep_json_string
    assert last_response.body.include? "nesting of 5 is too deep"
  end
  
  def test_upload_json
    json_tempfile_name = 'temp/tmp.json'
    File.delete( json_tempfile_name ) if File.exist?( json_tempfile_name );
    post '/delta3d_svg', 'json' => Rack::Test::UploadedFile.new('fixtures/full_hash_excerpt.json', 'application/json')
    assert Dir['temp/*'].include?('tmp.json')
    puts last_response.body
  end
  
  # def test_simple_post
  #   post '/regularize_fuzzy', 
  #     '{"witnesses" : [
  #           {"id" : "A", "tokens" : [
  #                   { "t" : "A" },
  #                   { "t" : "black" },
  #                   { "t" : "cat" }
  #                   ]}, 
  #           {"id" : "B", "tokens" : [
  #                   { "t" : "A" },
  #                   { "t" : "white" },
  #                   { "t" : "kitten.", "n" : "cat" }
  #                   ]}
  #           ]}'
  #   assert last_response.ok?
  #   assert last_response.body.include?( '{"n":"a","t":"A"}' )
  #   assert last_response.body.include?( '{"n":"black","t":"black"}' )
  #   assert last_response.body.include?( '{"n":"cat","t":"cat"}' )
  #   assert last_response.body.include?( '"id":"A"' )
  #   assert last_response.body.include?( '{"n":"a","t":"A"}' )
  #   assert last_response.body.include?( '{"n":"white","t":"white"}' )
  #   assert last_response.body.include?( '{"n":"kitten.","t":"kitten."}' )
  #   assert last_response.body.include?( '"id":"A"' )
  # end
  # 

end
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

  def test_nesting
    too_deep_json_string = '{ "line": { "position": { "token": { "one": { "two": { "three": { "four": { "todeep": [ "lemma1", "lemma2", "lemma3" ] } } } } } } } }'
    post '/delta3d_svg', 'json' => too_deep_json_string
    assert last_response.body.include? "nesting of 9 is too deep"
  end
  
  def test_upload_json
    post '/delta3d_svg', 'json' => Rack::Test::UploadedFile.new('fixtures/full_hash_converted.json', 'application/json')
    assert 4, last_response.body.scan(/DOCTYPE svg/).size
  end

end
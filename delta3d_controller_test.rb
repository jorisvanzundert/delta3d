require 'delta3d_controller.rb'
require 'test/unit'
require 'rack/test'

ENV['RACK_ENV'] = 'test'

class Delta3DControllerTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def mock_default_parameters
    { :spectrum_size => "50", :window_size => "1000", :spectrum_shift => "10", :shifts => "10", :bias_start => "", :bias_end => "", :sample => "100" }
  end
  
  def test_doc
    get '/doc'
    assert last_response.ok?
    assert last_response.body =~ /About this microservice/
  end

  def test_upload_text
    params = { 'file' => Rack::Test::UploadedFile.new('fixtures/a_text.txt', 'text/plain'), 'delta_parameters' => mock_default_parameters }
    post '/process', params
    token = last_response.body
      post '/svg_available', { :token => token }
      while last_response.body.eql?( "false" ) do
        post '/svg_available', { :token => token }
        sleep(3)
      end
    assert_equal "true", last_response.body
    post '/svg', { :token => token }
    assert_equal 4, last_response.body.scan(/DOCTYPE svg/).size
    assert_equal 5, last_response.body.scan(/\<\?/).size
  end

end
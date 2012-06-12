require 'rubygems'
require 'sinatra'
require 'json/pure'
require 'haml'

#set :environment, :development

#set :raise_errors, false
set :show_exceptions, false

class Delta3DController
 
  get '/doc' do
    haml :doc
  end
  
  post '/delta3d_svg' do
    content_type 'application/json'
    json_string = params['json'];
    json_string = params['json'][:tempfile].read if params['json'][:tempfile]
    json = JSON.parse(json_string, {:max_nesting => 4} )
    "That is bullshit"
  end
  
  error do
    "Something didn't went quite as expected - error: #{request.env['sinatra.error'].to_s}"
  end
  
end
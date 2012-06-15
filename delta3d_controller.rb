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
    # instantiate delta3d, pass json_string, respond svg result
  end
  
  error do
    "Something didn't went quite as expected - error: #{request.env['sinatra.error'].to_s}"
  end
   
end
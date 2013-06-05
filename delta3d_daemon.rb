require 'rubygems'
require 'daemons'

pwd = Dir.pwd
Daemons.run_proc('delta3d', {:dir_mode => :normal, :dir => '/var/run/sinatra', :log_dir => '/var/log/sinatra', :log_output => true }) do
  Dir.chdir(pwd)
  exec "ruby delta3d_controller.rb"
end

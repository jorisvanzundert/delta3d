require 'rubygems'
require 'daemons'

pwd = Dir.pwd
Daemons.run_proc('delta3d_controller.rb', {:dir_mode => :system, :dir => "/var/run"}) do
  Dir.chdir(pwd)
  exec "ruby delta3d_controller.rb"
end
delta3d
=======

### INSTALLING

- Download to a directory
- Create a secret (this is to hand out encrypted tokens to clients enabling them to retrieve generated svgs): ruby secret.rb
- Fire up delta3d_controller.rb ($>ruby delta3d_controller.rb)
- Visit yourdomain.org:4567 (port 4567 is default for Sinatra, adjust according to Sinatra docs)

### RUNNING AS DAEMON

- Make sure the directories /var/run/sinatra and /var/log/sinatra exist
- Now you can use $>ruby delta3d_daemon.rb start
- As usual this also gives you $>ruby delta3d_daemon.rb stop and $>ruby delta3d_daemon.rb restart capabilities
- You may want to use sudo -u user ruby delta3d_daemon.rb start to ensure a safe user space for this web application
- Make sure the user that is running the application as above has write access to /var/run/sinatra and /var/log/sinatra (and /tmp in the application's directory)

### DEPENDECIES

- Ruby 1.8.7+ (http://www.ruby-lang.org) 
- Ruby gems: sinatra, sinatra-contrib, json/pure
- gnuplot (http://www.gnuplot.info/)

### LICENSE

This software is licensed under MIT license, c.f. LICENSE.txt that should be contained in the same directory as this file.

JQuery, JQuery SVG plugin, and Plupload are licensed under GPLv2, c.f. LINCENSE_2.txt that should be contained in the same directory as this file.


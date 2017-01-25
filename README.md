# PinW 

A Web interface for [PIntron](http://pintron.algolab.eu/) 

Requirements
---------------

```
gem 'sqlite3'
gem 'sinatra', '~> 1.4.5'
gem 'sinatra-contrib', '~> 1.4.2'
gem 'net-ssh', '~> 2.9.1'
gem 'bcrypt', '~> 3.1.7'
```
See Gemfile for all the necessary gems


 Installation:
---------------
To install all the necessary gems you can use the `bundle` command

`$ bundle install`

Initialize database 

`$ rake db:setup`

Launch Development Server:

`$ rackup`

Documentation
--------------
For more information about installation and the web interface see the documentation


Docker Deployment
-----
Visit [Pinw-Deploy](https://github.com/AlgoLab/pinw-deploy) for more information. 

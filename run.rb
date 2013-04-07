require 'rubygems'
require 'bundler/setup'
require 'sinatra/base'
require 'redis'
require 'json'
require 'yaml'
require 'digest'
require 'time'
require 'colorize'
require 'rest-client'
require 'mail'
require './lib/notifu'

$stdout.reopen("./log/notifu.log", "a+")
$stdout.sync = true
$stderr.reopen("./log/http.log", "a+")
$stderr.sync = true

Notifu.set(
  :port => 8000,
  :logging => true,
  :environment => :production
)

Notifu.run!

require 'bundler/setup'
Bundler.require(:default)
require 'rubygems'
require 'thin'
require 'sinatra'
require 'redis'
require 'json'
require 'yaml'
require 'digest'
require 'time'
require 'colorize'
require 'rest-client'
require 'mail'
require File.dirname(__FILE__) + "/lib/notifu.rb"

Notifu.set(
  :run => false,
  :environment => :production,
  :port => 8000
)

run Notifu
#!/usr/bin/env ruby
require 'yaml'
require 'json'
require 'thor'

$basepath = File.dirname(__FILE__) + "/"
$actorpath = $basepath.gsub(/lib/, "actors")

required_files = Array.new
required_files << $basepath + "config.rb"
required_files << $basepath + "logger.rb"
required_files += Dir[ $basepath + 'cli/*.rb']
required_files << $basepath + "cli.rb"
required_files.each { |file| require file }

Notifu::CLI::Root.start(ARGV)
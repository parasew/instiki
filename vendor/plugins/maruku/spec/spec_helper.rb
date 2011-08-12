require 'rubygems'
require 'rspec'

lib_dir = File.dirname(__FILE__) + "/../lib"
$:.unshift lib_dir unless $:.include?(lib_dir)
$: << File.dirname(__FILE__) + "/../../syntax/lib/"
require 'maruku'

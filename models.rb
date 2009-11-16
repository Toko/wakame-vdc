#!/usr/bin/ruby

require 'rubygems'
require 'sequel'

DB = Sequel.connect('mysql://localhost/wakame_dcmgr?user=wakame_dcmgr&password=passwd')

# models
class Group < Sequel::Model; end

class User < Sequel::Model; end

class Instance < Sequel::Model; end

class ImageStorage < Sequel::Model; end

class HvSpec < Sequel::Model; end

class PhysicalHost < Sequel::Model; end

class HvController < Sequel::Model; end

class HvAgent < Sequel::Model; end


#!/usr/bin/ruby
#See this link: http://www.paracode.com/blog/2011/01/248/
#It seems to allow the code generator to work when binding to the erb
#What happens is as follows:
#http://stackoverflow.com/questions/3242470/problem-using-openstruct-with-erb
require 'ostruct'

class ErbBinding < OpenStruct
  def get_binding
    binding()
  end
end
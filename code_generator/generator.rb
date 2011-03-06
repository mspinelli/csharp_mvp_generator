#!/usr/bin/ruby

# Copyright (C) 2005-2011 by Atomic Object, LLC (http://atomicobject.com)
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require File.dirname(__FILE__) + '/config/environment.rb'
require_relative 'lib/visual_studio_proj_file_writer'
require_relative 'lib/prompt'
require_relative 'lib/erb_binding'
require 'erb'
require 'rexml/document'
require 'ostruct'
include REXML

#$proj_dir = '/../'
$project_filename = 'Puzzle.csproj'
$project_directory = '/../'

class String
  def camelize
    self.to_s.gsub(/\/(.?)/) {
      "::" + $1.upcase
    }.gsub(/(^|_)(.)/) {
      $2.upcase
    }
  end

  def underscore
    self.to_s.gsub(/::/, '/').gsub(
    /([A-Z]+)([A-Z])/,'\1_\2').gsub(
    /([a-z])([A-Z])/,'\1_\2').downcase
  end
end

class GeneratorBase
  attr_reader :files

  @@user_class = nil

  def self.inherited(c)
    @@user_class = c
  end

  def self.create_instance
    @@user_class.new
  end

  def file(args)
    @files ||= []
    @files << args
  end
end

at_exit do
  generator = GeneratorBase.create_instance
  puts nil
  puts generator.desc
  puts nil
  generator.generate
  files = generator.files

  data = {}
  generator.instance_variables.each do |var|
    data[var.to_s.gsub('@','')] = generator.instance_eval(var.to_s)
  end
  data_struct = ErbBinding.new(data)

  base_directory= File.dirname(__FILE__)
  output_directory = base_directory + $project_directory
  project_filename = $project_filename
  input_directory =  base_directory + "/templates/#{generator.class.to_s.underscore.gsub('_generator','')}/"

  files.each do |file|
    puts "generating #{output_directory + file[:out]}"
    File.open(input_directory + file[:in], 'r') do |input_file|
      template = ERB.new(input_file.read)
      File.open(output_directory + file[:out], 'w') do |output_file|
        binding = data_struct.send(:get_binding)
        output_file.write(template.result(binding))
      end
    end
  end

  document = nil
  File.open(output_directory + project_filename, 'r') do |project_file|
      document = Document.new(project_file)
  end

  include_el = XPath.first(  document.root, '//VisualStudioProject/CSHARP/Files/Include')
  if include_el.nil?
    puts 'Include element not found in project file'
    exit 2
  end

  files.each do |file|
    puts "adding #{output_directory + file[:out]} to #{project_filename}"
    options = file.reject { |k,v| [:in,:out].include?(k) }
    options[:rel_path] = file[:out].gsub("/","\\")
    attributes = Hash.new
    options.each do |k,v|
      attributes[k.to_s.camelize] = v
    end
    include_el.add_element('File', attributes)
  end

  puts 'storing project file'
  File.open(output_directory + project_filename, 'wb') do |proj_file|
    VisualStudioProjFileWriter.new(:doc =>   document).write(proj_file)
  end

  puts "Hit ENTER to exit"
  gets
end


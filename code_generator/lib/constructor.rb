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

class Class
	#
	# Declarative means to define object properties by passing a hash 
	# to the constructor, which will set the corresponding ivars.
	# Eg,
	#  class Horse
	#    constructor :name, :breed, :weight
	#  end
	#  Horse.new :name => 'Ed', :breed => 'Mustang', :weight => 342
	#
	# By default the ivars do not get accessors defined.
	# But you can get them auto-made if you want:
	#  class Horse
	#    constructor :name, :breed, :weight, :accessors => true
	#  end
	#  ...
	#  puts my_horse.weight
	# 
	# You can enforce strict argument checking with :strict option.
	# This means that the constructor will raise an error if you pass
	# more or fewer arguments than declared.
	# Eg,
	#  class Donkey
	#    constructor :age, :odor, :strict => true
	#  end
	# ... this forces you to pass both an age and odor key to the Donkey constructor.
	#
	def constructor(*attrs)
		# Look for embedded options in the listing:
		opts = attrs.find { |a| a.kind_of?(Hash) and attrs.delete(a) } 
		do_acc = opts.nil? ? false : opts[:accessors] == true
		require_args = opts.nil? ? false : opts[:strict] == true

		# Incorporate superclass's constructor keys
		if superclass.constructor_keys
			attrs = [attrs,superclass.constructor_keys].flatten
		end
		# Generate ivar assigner code lines
		assigns = ''
		attrs.each do |k|
			assigns += "@#{k.to_s} = args[:#{k.to_s}]\n"
		end 

		# If accessors option is on, declare accessors for the attributes:
		if do_acc
			self.class_eval "attr_accessor " + attrs.map {|x| ":#{x.to_s}"}.join(',')
		end

		# If strict is on, define the constructor argument validator method,
		# and setup the initializer to invoke the validator method.
		# Otherwise, insert lax code into the initializer.
		validation_code = "return if args.nil?"
		if require_args
			self.class_eval do 
			  def _validate_constructor_args(args)
					# First, make sure we've got args of some kind
					unless args and args.keys and args.keys.size > 0 
						raise ConstructorArgumentError.new(self.class.constructor_keys)
					end
					# Scan for missing keys in the argument hash
					a_keys = args.keys
					missing = []
					self.class.constructor_keys.each do |ck|
						unless a_keys.member?(ck)
							missing << ck
						end
						a_keys.delete(ck) # Delete inbound keys as we address them
					end
					if missing.size > 0 || a_keys.size > 0
						raise ConstructorArgumentError.new(missing,a_keys)
					end
				end
			end
			# Setup the code to insert into the initializer:
			validation_code = "_validate_constructor_args args "
		end

		# Generate the initializer code
		self.class_eval %{
			def initialize(args=nil)
				#{validation_code}
				#{assigns}
				setup if respond_to?(:setup)
			end
		}

		# Remember our constructor keys
		@_ctor_keys = attrs
	end

	# Access the constructor keys for this class
	def constructor_keys; @_ctor_keys; end
end

# Fancy validation exception, based on missing and extraneous keys.
class ConstructorArgumentError < RuntimeError
	def initialize(missing,rejected=[])
		err_msg = ''
		if missing.size > 0
			err_msg = "Missing constructor args [#{missing.join(',')}]"
		end
		if rejected.size > 0
			# Some inbound keys were not addressed earlier; this means they're unwanted
			if err_msg
				err_msg << "; " # Appending to earlier message about missing items
			else
				err_msg = ''
			end
			# Enumerate the rejected key names
			err_msg << "Rejected constructor args [#{rejected.join(',')}]"
		end
		super err_msg
	end
end

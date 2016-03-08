require 'active_support'
require 'active_support/json'
require 'active_support/core_ext/module/delegation'
require 'set'
require 'bigdecimal'

module ActiveSupport
  module JSON
    module Encoding
      class CircularReferenceError < StandardError; end

      class ActiveSupportEncoder
        attr_reader :options

        def initialize(options = nil)
          @options = options || {}
          @seen = Set.new
        end

        def encode(value, use_options = true)
          check_for_circular_references(value) do
            jsonified = use_options ? value.as_json(options_for(value)) : value.as_json
            jsonified.respond_to?(:encode_json) ? jsonified.encode_json(self) : encode(jsonified, false)
          end
        end

        # like encode, but only calls as_json, without encoding to string.
        def as_json(value, use_options = true)
          check_for_circular_references(value) do
            use_options ? value.as_json(options_for(value)) : value.as_json
          end
        end

        def options_for(value)
          if value.is_a?(Array) || value.is_a?(Hash)
            # hashes and arrays need to get encoder in the options, so that
            # they can detect circular references.
            options.merge(encoder: self)
          else
            options.dup
          end
        end

        def escape(string)
          self.class.escape(string)
        end

        class << self
          ESCAPED_CHARS = {
            "\u0000" => '\u0000', "\u0001" => '\u0001',
            "\u0002" => '\u0002', "\u0003" => '\u0003',
            "\u0004" => '\u0004', "\u0005" => '\u0005',
            "\u0006" => '\u0006', "\u0007" => '\u0007',
            "\u0008" => '\b',     "\u0009" => '\t',
            "\u000A" => '\n',     "\u000B" => '\u000B',
            "\u000C" => '\f',     "\u000D" => '\r',
            "\u000E" => '\u000E', "\u000F" => '\u000F',
            "\u0010" => '\u0010', "\u0011" => '\u0011',
            "\u0012" => '\u0012', "\u0013" => '\u0013',
            "\u0014" => '\u0014', "\u0015" => '\u0015',
            "\u0016" => '\u0016', "\u0017" => '\u0017',
            "\u0018" => '\u0018', "\u0019" => '\u0019',
            "\u001A" => '\u001A', "\u001B" => '\u001B',
            "\u001C" => '\u001C', "\u001D" => '\u001D',
            "\u001E" => '\u001E', "\u001F" => '\u001F',
            "\u2028" => '\u2028', "\u2029" => '\u2029',
            '"'  => '\"',
            '\\' => '\\\\',
            '>' => '\u003E',
            '<' => '\u003C',
            '&' => '\u0026'}

          ESCAPE_REGEX_WITH_HTML = /[\u0000-\u001F\u2028\u2029"\\><&]/u
          ESCAPE_REGEX_WITHOUT_HTML = /[\u0000-\u001F\u2028\u2029"\\]/u

          def escape(string)
            string = string.encode ::Encoding::UTF_8, undef: :replace
            regex = Encoding.escape_html_entities_in_json ? ESCAPE_REGEX_WITH_HTML : ESCAPE_REGEX_WITHOUT_HTML
            %("#{string.gsub regex, ESCAPED_CHARS}")
          end
        end

        private
          def check_for_circular_references(value)
            unless @seen.add?(value.__id__)
              raise CircularReferenceError, 'object references itself'
            end
            yield
          ensure
            @seen.delete(value.__id__)
          end
      end

      class << self
        remove_method :encode_big_decimal_as_string, :encode_big_decimal_as_string= rescue NameError

        # If false, serializes BigDecimal objects as numeric instead of wrapping
        # them in a string.
        attr_accessor :encode_big_decimal_as_string
      end

      self.encode_big_decimal_as_string = true
    end
  end
end

class TrueClass
  def encode_json(encoder) #:nodoc:
    to_s
  end
end

class FalseClass
  def encode_json(encoder) #:nodoc:
    to_s
  end
end

class NilClass
  def encode_json(encoder) #:nodoc:
    'null'
  end
end

class String
  def encode_json(encoder) #:nodoc:
    ActiveSupport::JSON::Encoding::ActiveSupportEncoder.escape(self)
  end
end

class Numeric
  def encode_json(encoder) #:nodoc:
    to_s
  end
end

class BigDecimal
  # A BigDecimal would be naturally represented as a JSON number. Most libraries,
  # however, parse non-integer JSON numbers directly as floats. Clients using
  # those libraries would get in general a wrong number and no way to recover
  # other than manually inspecting the string with the JSON code itself.
  #
  # That's why a JSON string is returned. The JSON literal is not numeric, but
  # if the other end knows by contract that the data is supposed to be a
  # BigDecimal, it still has the chance to post-process the string and get the
  # real value.
  #
  # Use <tt>ActiveSupport.encode_big_decimal_as_string = true</tt> to
  # override this behavior.

  remove_method :as_json

  def as_json(options = nil) #:nodoc:
    if finite?
      ActiveSupport::JSON::Encoding.encode_big_decimal_as_string ? to_s : self
    else
      nil
    end
  end

  def encode_json(encoder) #:nodoc:
    to_s
  end
end

class Array
  remove_method :as_json

  def as_json(options = nil) #:nodoc:
    # use encoder as a proxy to call as_json on all elements, to protect from circular references
    encoder = options && options[:encoder] || ActiveSupport::JSON::Encoding::ActiveSupportEncoder.new(options)
    map { |v| encoder.as_json(v, options) }
  end

  def encode_json(encoder) #:nodoc:
    "[#{map { |v| encoder.encode(v, false) } * ','}]"
  end
end

class Hash
  remove_method :as_json

  def as_json(options = nil) #:nodoc:
    # create a subset of the hash by applying :only or :except
    subset = if options
      if attrs = options[:only]
        slice(*Array(attrs))
      elsif attrs = options[:except]
        except(*Array(attrs))
      else
        self
      end
    else
      self
    end

    # use encoder as a proxy to call as_json on all values in the subset, to protect from circular references
    encoder = options && options[:encoder] || ActiveSupport::JSON::Encoding::ActiveSupportEncoder.new(options)
    Hash[subset.map { |k, v| [k.to_s, encoder.as_json(v, options)] }]
  end

  def encode_json(encoder) #:nodoc:
    # values are encoded with use_options = false, because we don't want hash representations from ActiveModel to be
    # processed once again with as_json with options, as this could cause unexpected results (i.e. missing fields);

    # on the other hand, we need to run as_json on the elements, because the model representation may contain fields
    # like Time/Date in their original (not jsonified) form, etc.

    "{#{map { |k,v| "#{encoder.encode(k.to_s)}:#{encoder.encode(v, false)}" } * ','}}"
  end
end

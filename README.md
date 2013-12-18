Active Support JSON Encoder
===========================

A pure-Ruby ActiveSupport JSON encoder. This was the default encoder used
by ActiveSupport prior to Rails 4.1. The main advantage of using this
encoder over the new default is for the `#encode_json` support (see below).

Installation
------------

Simply include this gem in your Gemfile:

    gem 'activesupport-json_encoder', github: 'rails/activesupport-json_encoder'

Configuration
-------------

By default, ActiveSupport encodes `BigDecimal` objects as a string:

```ruby
{ big_number: BigDecimal.new('12345678901234567890') }.to_json # => "{\"big_number\":\"12345678901234567890.0\"}"
```

To change this, you can set `ActiveSupport.encode_big_decimal_as_string` to
`false`:

```ruby
ActiveSupport.encode_big_decimal_as_string = false
{ big_number: BigDecimal.new('12345678901234567890') }.to_json # => "{\"big_number\":12345678901234567890.0}"
```

Beware that you may lose precision on the consuming-end if you do this:

```javascript
// Parsing this in JavaScript in the browser
JSON.parse("{\"big_number\":12345678901234567890.0}").big_number // => 12345678901234567000
```

JSON Serialization for Custom Objects
-------------------------------------

By default, when the encoder encounters a Ruby object that it does not
recognize, it will serilizes its instance variables:

```ruby
class MyClass
  def initialize
    @foo = :bar
  end
end

MyClass.new.to_json # => "{\"foo\":\"bar\"}"
```

There are two ways to customize this behavior on a per-class basis. Typically,
you should override `#as_json` to return a Ruby-representation of your object.
Any options passed to `#to_json` will be made available to this method:

```ruby
class MyClass
  def as_json(options = {})
    options[:as_array] ? [:foo, :bar] : {foo: :bar}
  end
end

MyClass.new.to_json # => "{\"foo\":\"bar\"}"
MyClass.new.to_json(as_array: true) # => "[\"foo\",\"bar\"]"
```

This method is supported by all encoders.

However, sometimes this might not give you enough control. For example, you
might want to encode numeric values in a certain format. In this case, you can
override the `#encoder_json` method. This method has access to the `Encoder`
object and is expected to return a `String` that would be injected to the JSON
output directly:

```ruby
class Money
  def initialize(dollars, cents)
    @dollars = dollars
    @cents = cents
  end

  def as_json(options = nil)
    # Opt-out from the default Object#as_json
    self
  end

  def encode_json(encoder)
    if @cents.to_i < 10
      "#{@dollars.to_i}.0#{@cents.to_i}"
    else
      "#{@dollars.to_i}.#{@cents.to_i}"
    end
  end
end

{ price: Money.new(0,10) }.to_json # => "{\"price\":0.10}"
```

Beware that this function is specific to this gem and is not supported by
other encoders. You should also be extra careful to return valid JSON because
the return value of this method will be injected into the output with no
sanitization whatsoever. Use this method with extreme caution, especially
when dealing with user input.

Dependencies
------------

* `activesupport` >= 4.1.0.beta

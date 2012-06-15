require 'rubygems'
require 'json/pure'

class LegacyHashConverter

  def initialize( source )
    @text_hash = JSON.load( source )
    @token_size = 0
    @lemma_size = 0
    @max_position = 0
  end
  
  def each_value(&block)
    @text_hash.each_value(&block)
  end
  
  def line_size
    @text_hash.size
  end
  
  def token_size
    @text_hash.each_value { |position| position.each_key { |pos| @token_size += 1 } } if @token_size == 0
    @token_size
  end
    
  def lemma_size
    @text_hash.each_value { |position| position.each_value { |token_lemmas| token_lemmas.each_value { |lemmas| @lemma_size += lemmas.size } } } if @lemma_size == 0
    @lemma_size
  end

  def max_position
    @text_hash.each_value { |position| position.each_key { |pos| @max_position = Integer(pos) if Integer(pos) > @max_position } } if @max_position == 0
    @max_position
  end

  def convert
    lines = Array.new    
    @text_hash.each do |line_number,positions_hash|
      positions = Array.new    
      positions_hash.each do |position,token_hash|
        token_hash.each do |token_surface,lemmas|
          token = { "surface" => token_surface, "lemmas" => lemmas }
          positions.push( { "id" => position, "token" => token } )
        end
      end
      lines.push( { "id" => line_number, "positions" => positions } )
    end
    converted = { "lines" => lines }
  end

  # from
  # { line: { position: { token: [ lemma1, lemma2, ...] } }
  # to
  # { "lines" => [ { "id" => "1", "positions" => [ { "id" => "100", token => { "surface" => "aword", "lemmas" => [ "lemma1", "lemma2" ] } } ] } ] }

end

puts "Loading JSON"
text_hash = LegacyHashConverter.new( File.new('fixtures/full_hash.json') )
puts "Legacy loaded"
puts "#{text_hash.line_size} lines allocated"
puts "#{text_hash.token_size} tokens read"
puts "#{text_hash.lemma_size} lemmas filed"
puts "Converting"
new_hash = text_hash.convert
puts "Generatig new JSON"
new_json = JSON.generate( new_hash )
puts "Writing new file"
new_File = File.new("fixtures/full_hash_converted.json", "w")
new_File.write(new_json)
new_File.close
puts "Converted file written to fixtures/full_hash_converted.json"

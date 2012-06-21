require 'rubygems'
require 'json/pure'

class Delta3D

  def initialize( json_string )
    @token_size = 0
    @max_position = 0

    source = JSON.parse(json_string, {:max_nesting => 8} )

    # Valid structures
    # { "lines": [ { "id": line_id, "positions": [ { "id": position_id, "token": { "surface": surface, "lemmas": [ lemma1, lemma2, ... ] } }, ... ] }, ... ] }
    # { "lines": [ { "id": line_id, "positions": [ { "id": position_id, "token": { "surface": surface } }, ... ] }, ... ] }
    # { "positions": [ { "id": position_id, "token": { "surface": surface, "lemmas": [ lemma1, lemma2, ... ] } }, ... ] }
    # { "positions": [ { "id": position_id, "token": { "surface": surface } }, ... ] }
  
    # NB Never { token: [ lemma1, lemma2, ...] } (Hash order is not guaranteed)
    # NB It is JSON input, so we don't have to worry about cycles
 
    # E.g. { "lines" => [ { id => "1", "positions" => [ { id => "100", token => { "surface" => "aword", "lemmas" => [ "lemma1", "lemma2" ] } } ] } ] }
    
    raise InvalidJSONStructureException, "JSON input has not the right structure" if source.size != 1
    first_key = source.keys.first 
    self.send( first_key, source[ first_key ] ) if ["lines", "positions"].include? first_key
  end
    
  def lines( lines_source )
    lines_unordered = convert( lines_source )
    @lines_ordered = lines_unordered.sort{ |line_a,line_b| line_a.line_id <=> line_b.line_id }
  end

  def convert( lines_source )
    lines = Array.new
    lines_source.each { |line| lines.push( Line.new(line) ) }
    lines
  end
  
  def lines_ordered
    @lines_ordered
  end
  
  def token_size
    lines_ordered.each { |line| @token_size += line.tokens.size } if @token_size == 0
    @token_size
  end
    
  def max_position
    if @max_position == 0
      lines_ordered.each do |line| 
        line.tokens.each do |token|
          @max_position = token.position if token.position > @max_position
        end
      end
    end
    @max_position
  end

end


class Background < Hash
end

class BackgroundFactory

  def self.create( ordered_lines, parts )
    frequencies = Hash.new
    lemma_counts = Array.new(parts,0)
    part_size = ( ordered_lines.size.to_f / parts.to_f ).ceil
    parts.times do |part|
      ordered_lines[(part*part_size),part_size].each do |line| 
        line.tokens.each do |token|
          token.lemmas.each do |lemma|
            frequencies[lemma] = Array.new(parts,0) if !frequencies.include?( lemma )
            frequencies[lemma][part] += 1
            lemma_counts[part] += 1
          end
        end
      end
    end
    background = Background.new
    frequencies.each do |lemma, frequencies|
      frequencies.each_index { |part| frequencies[part] = frequencies[part].to_f/lemma_counts[part].to_f}
      mean = ( frequencies.inject(0) { |sum,f| sum + f } ) / parts
      stdev = Math.sqrt( ( frequencies.inject(0) { |stdevsum,f| stdevsum +  (f-mean)**2 } ) / parts )
      background[lemma] = [mean,stdev]
    end
    background
  end

end


class Window
  
  def initialize( ordered_lines, window_size )
    @lemma_count = 0
    @frequencies = Hash.new
    @window_size = window_size
    @lines = ordered_lines
    @lines[0, @window_size].each do |line|
      add_frequencies( line )
    end
  end
  
  def frequencies
    @frequencies
  end
  
  def lemma_count
    @lemma_count
  end
  
  def add_frequencies( line )
    line.tokens.each do |token|
      token.lemmas.each do |lemma|
        !frequencies.include?( lemma ) ? frequencies[lemma] = 1 : frequencies[lemma] += 1
        @lemma_count += 1
      end
    end
  end

  def remove_frequencies( line )
    line.tokens.each do |token|
      token.lemmas.each do |lemma|
        frequencies[lemma] -= 1
        frequencies.delete(lemma) if frequencies[lemma] == 0
        @lemma_count -= 1
      end
    end
  end
  
  def each(&block)
    @lines[@window_size, @lines.length].each_with_index do |line,index|
      yield self
      add_frequencies( line )
      remove_frequencies( @lines[index] )
    end
    yield self
  end
  
end


class Line
  
  def initialize( line_source )
    guard_invalid if !line_source.is_a? Hash
    guard_invalid if line_source["id"].nil?
    guard_invalid if line_source["positions"].nil?
    @line_id = Integer( line_source["id"] )
    @tokens = line_source["positions"].collect { |position| Token.new( position ) }
  end

  def guard_invalid
    raise InvalidJSONStructureException, "JSON input has not the right structure" 
  end
  
  def line_id
    @line_id
  end
  
  def tokens
    @tokens
  end
  
end


class Token

  def initialize( token_source )
    guard_invalid if !token_source.is_a? Hash
    guard_invalid if token_source.size > 2
    guard_invalid if token_source["id"].nil? or token_source["token"].nil? 
    guard_invalid if token_source["token"]["surface"].nil?
    @position = Integer( token_source["id"] )
    @surface = token_source["token"]["surface"]
    @lemmas = token_source["token"]["lemmas"]
  end

  def guard_invalid
    raise InvalidJSONStructureException, "JSON input has not the right structure" 
  end

  def position
    @position
  end
  
  def surface
    @surface
  end
  
  def lemmas
    @lemmas
  end
  
end


class InvalidJSONStructureException < StandardError
end

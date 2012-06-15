require 'rubygems'
require 'json/pure'

class Delta3D

  def initialize( json_string )
    @token_size = 0
    @max_position = 0
    source = JSON.parse(json_string, {:max_nesting => 7} )

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
  
  def lines( lines_unordered )
    @lines_ordered = lines_unordered.sort do |line_a,line_b|
      guard_invalid if !line_a.is_a? Hash or !line_b.is_a? Hash
      guard_invalid if (line_a["id"].nil? or line_b["id"].nil?)
      Integer( line_a["id"] ) <=> Integer( line_b["id"] ) 
    end
  end

  def guard_invalid
    raise InvalidJSONStructureException, "JSON input has not the right structure" 
  end
  
  def lines_ordered
    @lines_ordered
  end
  
  def token_size
    lines_ordered.each { |line| @token_size += line["positions"].size } if @token_size == 0
    @token_size
  end
    
  def max_position
    if @max_position == 0
      lines_ordered.each do |line| 
        line["positions"].each do |position|
          @max_position = Integer(position["id"]) if Integer(position["id"]) > @max_position
        end
      end
    end
    @max_position
  end
  
  def create_background(n)
    quotient = ( max_position.to_f / n.to_f ).ceil
    lemmas_in_quotients = Array.new(n,0)
    background = lines_ordered.inject(Hash.new) do |base, line| 
      line["positions"].each do |position_token|
        position_token["token"]["lemmas"].each do |lemma|
          base[lemma] = Array.new(n,0) if !base.include?( lemma )
          position = position_token["id"]
          index = (((Integer(position))-1)/quotient).floor
          if !(index>=n)
            base[lemma][index] += 1 
            lemmas_in_quotients[index] += 1
          else
            puts "#{position}: #{index} (#{token_size}, #{n})"
          end
        end
      end
      base
    end
    background.each do |lemma, frequencies|
      frequencies.each_index { |index| frequencies[index] = frequencies[index].to_f/lemmas_in_quotients[index].to_f}
      mean = ( frequencies.inject(0) { |sum,f| sum + f } ) / n
      stdev = Math.sqrt( ( frequencies.inject(0) { |stdevsum,f| stdevsum +  (f-mean)**2 } ) / n )
      background[lemma] = [mean, stdev]
    end
  background
  end
  
end

class InvalidJSONStructureException < StandardError
end

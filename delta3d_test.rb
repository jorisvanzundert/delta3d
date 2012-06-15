require 'rubygems'
require 'delta3d.rb'
require 'test/unit'
require 'json/pure'

class Delta3DTest < Test::Unit::TestCase
    
  def test_not_numbers_as_key
    lines_arr = Array.new
    lines_arr.push( { "id" => "3", "positions" => "whatever" } )
    lines_arr.push( { "id" => "foo", "positions" => "whatever2" } )
    lines_arr.push( { "id" => "2", "positions" => "whatever3" } )
    text_hash = { "lines" => lines_arr }
    begin 
      delta3d = Delta3D.new( JSON.generate( text_hash ) )
    rescue Exception => excp
      assert( excp.message.index('invalid value for Integer: "foo"') != nil )
    end
  end
  
  def test_too_many_outer_keys
    text_hash = { "lines" => [ { "id" => "1", "positions" => "whatever" }, { "id" => "2", "positions" => "whatever2" } ], "invalid" => [ "100" ] } 
    assert_raise( InvalidJSONStructureException ) do 
      delta3d = Delta3D.new( JSON.generate( text_hash ) )
    end
  end
  
  def test_lines_ordering
    #  "lines" => [ { id => "1", "positions" => [ { id => "100", token => { "surface" => "aword", "lemmas" => [ "lemma1", "lemma2" ] } } ] } ] }
    lines_arr = Array.new
    lines_arr.push( { "id" => "3", "positions" => "whatever" } )
    lines_arr.push( { "id" => "1", "positions" => "whatever2" } )
    lines_arr.push( { "id" => "2", "positions" => "whatever3" } )
    text_hash = { "lines" => lines_arr }
    delta3d = Delta3D.new( JSON.generate( text_hash ) )
    id = "0"
    delta3d.lines_ordered.each do |line| 
      assert( Integer( line["id"] ) == (Integer( id ) + 1)  ) 
      id = line["id"]
    end
  end
  
  # def test_real_life_ordering
  #   text_json = File.read( 'fixtures/full_hash_excerpt_converted.json' )
  #   delta3d = Delta3D.new( text_json )
  #   id = "0"
  #   delta3d.lines_ordered.each do |line| 
  #     assert( Integer( line["id"] ) == (Integer( id ) + 1)  ) 
  #     id = line["id"]
  #   end
  # end

  def test_lines_structure_fails_id
    #  "lines" => [ { id => "1", "positions" => [ { id => "100", token => { "surface" => "aword", "lemmas" => [ "lemma1", "lemma2" ] } } ] } ] }
    lines_arr = Array.new
    lines_arr.push( { "id" => "3", "positions" => "whatever" } )
    lines_arr.push( { "not_an_id" => "1", "positions" => "whatever2" } )
    lines_arr.push( { "id" => "2", "positions" => "whatever3" } )
    text_hash = { "lines" => lines_arr }
    assert_raise( InvalidJSONStructureException ) do 
      delta3d = Delta3D.new( JSON.generate( text_hash ) )
    end
  end
  
  def test_lines_structure_fails_hash
    #  "lines" => [ { id => "1", "positions" => [ { id => "100", token => { "surface" => "aword", "lemmas" => [ "lemma1", "lemma2" ] } } ] } ] }
    lines_arr = Array.new
    lines_arr.push( { "id" => "3", "positions" => "whatever" } )
    lines_arr.push( [ 1, 2, 3 ] )
    lines_arr.push( { "id" => "2", "positions" => "whatever3" } )
    text_hash = { "lines" => lines_arr }
    assert_raise( InvalidJSONStructureException ) do 
      delta3d = Delta3D.new( JSON.generate( text_hash ) )
    end
  end
  
  # def test_large
  #   text_json = File.read( 'fixtures/full_hash_converted.json' )
  #   delta3d = Delta3D.new( text_json )
  #   assert_equal( 63089, delta3d.token_size )
  #   assert_equal( 74301, delta3d.max_position )
  # end
  
  def test_background
    text_json = File.read( 'fixtures/full_hash_excerpt_converted.json' )
    delta3d = Delta3D.new( text_json )
    puts delta3d.create_background(2).inspect
  end

end
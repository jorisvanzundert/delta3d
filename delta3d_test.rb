require 'rubygems'
require 'delta3d.rb'
require 'test/unit'
require 'json/pure'

class Delta3DTest < Test::Unit::TestCase
   
  def mock_positions
    token_array = Array.new
    token_array.push( { "id" => "102", "token" => { "surface" => "aword", "lemmas" => [ "lemma1", "lemma2" ] } } )
    token_array.push( { "id" => "101", "token" => { "surface" => "aword2", "lemmas" => [ "lemma3", "lemma4" ] } } )
    token_array.push( { "id" => "103", "token" => { "surface" => "aword3", "lemmas" => [ "lemma5", "lemma6" ] } } )
  end
  
  def test_not_numbers_as_key
    lines_arr = Array.new
    lines_arr.push( { "id" => "3", "positions" => mock_positions } )
    lines_arr.push( { "id" => "foo", "positions" => mock_positions } )
    lines_arr.push( { "id" => "2", "positions" => mock_positions } )
    text_hash = { "lines" => lines_arr }
    assert_raise( ArgumentError ) do
      delta3d = Delta3D.new( JSON.generate( text_hash ) )
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
    lines_arr.push( { "id" => "3", "positions" => mock_positions } )
    lines_arr.push( { "id" => "1", "positions" => mock_positions } )
    lines_arr.push( { "id" => "2", "positions" => mock_positions } )
    # This kind of screams for duplicate detection, no?
    # Duplicates (of positions for instance) are structurally not wrong, but conceptually odd.
    # In practice last in will overwrite other values
    text_hash = { "lines" => lines_arr }
    delta3d = Delta3D.new( JSON.generate( text_hash ) )
    id = 0
    delta3d.lines_ordered.each do |line| 
      assert( line.line_id == id+1  ) 
      id = line.line_id
    end
  end

  def test_token_id_not_number
    token_hash = { "id" => "foo", "token" => { "surface" => "aword", "lemmas" => [ "lemma1", "lemma2" ] } }
    assert_raise( ArgumentError ) do
      delta3d = Token.new(token_hash)
    end
  end
  
  def test_token_hash_wrong_size
    token_hash = { "id" => "100", "token" => { "surface" => "aword", "lemmas" => [ "lemma1", "lemma2" ] }, "wrong" => "error" }
    assert_raise( InvalidJSONStructureException ) do 
      token = Token.new(token_hash)
    end
  end

  def test_token_not_hash
    token_hash = [ "id", "100", "token", "surface", "aword", "lemmas" ]
    assert_raise( InvalidJSONStructureException ) do 
      token = Token.new(token_hash)
    end
  end

  def test_token_hash_invalid
    invalid_token_hashes = Array.new
    invalid_token_hashes.push( { "noid" => "100", "token" => { "surface" => "aword", "lemmas" => [ "lemma1", "lemma2" ] } } )
    invalid_token_hashes.push( { "id" => "100", "notoken" => { "surface" => "aword", "lemmas" => [ "lemma1", "lemma2" ] } } )
    invalid_token_hashes.push( { "id" => "100", "token" => { "nosurface" => "aword", "lemmas" => [ "lemma1", "lemma2" ] } } )
    invalid_token_hashes.each do |position| 
      assert_raise( InvalidJSONStructureException ) do 
        token = Token.new(position)
      end
    end
  end
  
  def test_no_lemmas_in_token_okay
    token_hash = { "id" => "100", "token" => { "surface" => "aword" } }
    token = Token.new(token_hash)
    assert_equal( Integer( token_hash["id"] ), token.position )
    assert_equal( token_hash["token"]["surface"], token.surface )
    assert( token.lemmas.nil? )
  end

  def test_token
    token_array = Array.new
    positions_hash = { "positions" => token_array }
    token_array.push( { "id" => "100", "token" => { "surface" => "aword", "lemmas" => [ "lemma1", "lemma2" ] } } )
    token_array.push( { "id" => "120", "token" => { "surface" => "aword2", "lemmas" => [ "lemma3", "lemma4" ] } } )
    token_array.push( { "id" => "103", "token" => { "surface" => "aword3", "lemmas" => [ "lemma5", "lemma6" ] } } )
    positions_hash["positions"].each do |position|
      token = Token.new(position)
      assert_equal( Integer( position["id"] ), token.position )
      assert_equal( position["token"]["surface"], token.surface )
      token.lemmas.each{ |lemma| assert( position["token"]["lemmas"].include? lemma ) }
    end
  end
    
  def test_real_life_ordering
    text_json = File.read( 'fixtures/full_hash_excerpt_converted.json' )
    delta3d = Delta3D.new( text_json )
    id = 0
    delta3d.lines_ordered.each do |line| 
      assert( line.line_id > id )
      id = line.line_id
    end
  end
  
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

  def test_lines_structure_fails_positions
    #  "lines" => [ { id => "1", "positions" => [ { id => "100", token => { "surface" => "aword", "lemmas" => [ "lemma1", "lemma2" ] } } ] } ] }
    lines_arr = Array.new
    lines_arr.push( { "id" => "3", "NO_positions_HERE" => "whatever" } )
    lines_arr.push( { "id" => "1", "positions" => "whatever2" } )
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
  
  def test_real_life_size
    text_json = File.read( 'fixtures/full_hash_converted.json' )
    delta3d = Delta3D.new( text_json )
    assert_equal( 63089, delta3d.token_size )
    assert_equal( 74301, delta3d.max_position )
    assert_nothing_raised do
      BackgroundFactory.create(delta3d.lines_ordered,10)
    end
  end
  
  def mock_lines_source
    random_vocabular = ["a", "word", "seldom", "travels", "alone", "its", "companions", "are", "characters"]
    random_lemmas = [ "lem1", "lem2", "lem3", "lem4", "lem5", "lem6" ]
    lines_source = Array.new
    line_count = 10
    position_count = 1
    line_count.times do |line_number|
      position_array = Array.new
      token_count = 3 + rand(3)
      token_count.times do 
        lemma_array = Array.new
        (1 + rand(2)).times do
          lemma_array.push( random_lemmas[rand(random_lemmas.length)] )
        end
        surface = random_vocabular[rand(random_vocabular.length)]
        token_hash = { "surface" => surface, "lemmas" => lemma_array }
        position_array.push( { "id" => "#{position_count}", "token" => token_hash } )
        position_count =+ 1
      end
      lines_source.push( { "id" => "#{line_number}", "positions" => position_array } )
    end
    lines_source
  end
  
  def test_window
    lines_source = mock_lines_source
    test_windows = []
    8.times do |line_number|
      test_window = { "lines" => lines_source[line_number,3], "lemma_count" => 0, "frequencies" => {} }
      test_window["lines"].inject(test_window) do |test_window,line| 
        line["positions"].inject(test_window) do |test_window,position|
          position["token"]["lemmas"].inject(test_window) do |test_window,lemma|
            test_window["lemma_count"] += 1
            test_window["frequencies"].include?(lemma) ? test_window["frequencies"][lemma] += 1 : test_window["frequencies"][lemma] = 1
            test_window
          end
        end
      end
      test_windows.push( test_window )
    end
    lines_arr = lines_source.collect { |line| Line.new(line) }
    window_size = 3 # with 10 lines, we expect 8 windows of 3 lines
    window = Window.new( lines_arr, window_size )
    window_count = 0
    window.each do |window|
      #puts test_windows[window_count]["lines"].inspect
      assert_equal test_windows[window_count]["lemma_count"], window.lemma_count
      assert_equal test_windows[window_count]["frequencies"], window.frequencies
      window_count += 1
    end
    assert_equal 8, window_count 
  end

  def test_background
    lines_source = mock_lines_source
    lines_arr = lines_source.collect { |line| Line.new(line) }
    parts = 3
    test_stats = Array.new(3) {[0,0]} #3 parts, frequency, total lemmas in part
    partsize = 4
    parts.times do |part|
      lines_arr[(part*partsize),partsize].each do |line|
        line.tokens.each do |token|
          token.lemmas.each do |lemma|
            test_stats[part][0] += 1 if lemma.eql?( "lem6" )
            test_stats[part][1] += 1
          end
        end
      end
    end
    mean = ( test_stats.collect{ |stat| stat[0].to_f/stat[1].to_f }.inject(0) { |sum,f| sum + f } ) / parts
    background = BackgroundFactory.create(lines_arr,3)
    assert_equal mean, background["lem6"][0]
  end

end
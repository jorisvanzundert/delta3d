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
   
   def test_nesting
     too_deep_json_string = '{ "line": { "position": { "token": { "one": { "two": { "three": { "four": { "todeep": [ "lemma1", "lemma2", "lemma3" ] } } } } } } } }'
     exception = assert_raise( JSON::NestingError ) do 
       delta3d = Delta3D.new( too_deep_json_string )
     end
     assert_equal "nesting of 9 is too deep", exception.message
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
   
   def test_no_lemma_causes_token_to_be_lemma
     token_hash = { "id" => "100", "token" => { "surface" => "aword" } }
     token = Token.new(token_hash)
     assert_equal( Integer( token_hash["id"] ), token.position )
     assert_equal( token_hash["token"]["surface"], token.surface )
     assert( token.lemmas.size == 1 )
     assert_equal( "aword", token.lemmas[0] )
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
     start = Time.now
     delta3d = Delta3D.new( text_json )
     assert_equal( 63089, delta3d.token_size )
     assert_equal( 74301, delta3d.max_position )
     assert_equal( 11202, delta3d.lines_ordered.size )
     lemma_counts = Hash.new
     text_json.scan(/lemmas[^\]]*\]/).inject(lemma_counts) do |lemma_counts,matched| 
       matches = matched.split( "\"" )
       matches[2,matches.length-1].each_with_index do |some_string,index|
         if index.even?
           lemma_counts.include?(some_string) ? lemma_counts[some_string] += 1 : lemma_counts[some_string] = 1
         end
       end
       lemma_counts
     end
     total_lemmas_in_delta = delta3d.lines_ordered.inject(0) {|total_lemmas,line| line.tokens.inject(total_lemmas) {|total_lemmas,token| total_lemmas += token.lemmas.size } }
     total_lemmas_test = lemma_counts.inject(0) {|total,lemma| total += lemma[1] }
     assert_equal total_lemmas_test, total_lemmas_in_delta
     assert_nothing_raised do
       background_start = Time.now
       background = BackgroundFactory.create(delta3d.lines_ordered,10)
       assert_equal lemma_counts.size, background.size
       assert (start-Time.now) < 1
     end
     assert (start-Time.now) < 15
   end
   
   def mock_lines_source
    random_vocabular = ["a", "word", "seldom", "travels", "alone", "its", "companions", "are", "characters"]
    random_lemmas = [ "lem1", "lem2", "lem3", "lem4", "lem5", "lem6", "lem7", "lem8", "lem9", "lem10" ]
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
        position_count += 1
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
    assert background.size > 0
    assert_equal mean, background.get("lem6").mean_freq
  end
  
  def test_bias
    lines_source = mock_lines_source
    lines_arr = lines_source.collect { |line| Line.new(line) }
    unique_lemmas = lines_arr.inject({}){ |unique_lemmas, line| line.tokens.inject(unique_lemmas){ |unique_lemmas, token| token.lemmas.inject(unique_lemmas){ |unique_lemmas, lemma| unique_lemmas[lemma]=0; unique_lemmas} } }
    background = BackgroundFactory.create(lines_arr,3)
    bias = Bias.new( background, lines_arr, 2, 3 )
    unique_lemmas.each do |lemma,value| 
      assert !bias.zscore(lemma).nil?
    end
    assert_raise( StandardError ) do
      bias = Bias.new( background, lines_arr, 2, 17 )
    end
    assert_raise( StandardError ) do
      bias = Bias.new( background, lines_arr, 3, 1 )
    end
    bias = Bias.new( background, lines_arr, 0, 0 )
    assert_equal 0, bias.zscore("anything")
  end
  
  def test_real_plot
    text_json = File.read( 'fixtures/full_hash_converted.json' )
    delta3d = Delta3D.new( text_json )
    plot_data = delta3d.calculate( {:spectrum_shift => 10, :bias_end => 0, :bias_start => 0} )
    assert_nothing_raised do
      assert 4, delta3d.plot( plot_data ).scan(/DOCTYPE svg/).size
    end
  end
  
  def test_linefromtokens
    positions = mock_lines_source.reduce([]){ |positions, mock_line| positions + mock_line["positions"] }
    positions.map do |position| 
      position["t"] = position["token"]
      position.delete("token")
      position["t"]["s"]=position["t"]["surface"]
      position["t"]["l"]=position["t"]["lemmas"]
      position["t"].delete("surface")
      position["t"].delete("lemmas")
      position
    end
    delta3d = Delta3D.new( JSON.generate( {"p" => positions} ) )
    assert_equal (positions.size/5.to_f).ceil, delta3d.lines_ordered.size
    total_tokens = delta3d.lines_ordered.inject(0){ |total_tokens, line| total_tokens += line.tokens.size }
    assert_equal positions.size, total_tokens
  end
  
  def test_lemmaless
    positions = mock_lines_source.reduce([]){ |positions, mock_line| positions + mock_line["positions"] }
    lemmas_in = []
    positions.map do |position| 
      position["t"] = position["token"]
      position.delete("token")
      position["t"]["s"]=position["t"]["surface"]
      position["t"].delete("surface")
      position["t"].delete("lemmas")
      lemmas_in.push( position["t"]["s"] )
      position
    end
    delta3d = Delta3D.new( JSON.generate( {"p" => positions} ) )
    assert_equal (positions.size/5.to_f).ceil, delta3d.lines_ordered.size
    total_tokens = delta3d.lines_ordered.inject(0){ |total_tokens, line| total_tokens += line.tokens.size }
    assert_equal positions.size, total_tokens
    delta3d.lines_ordered.each{ |line| line.tokens.each{ |token| assert lemmas_in.include? token.lemmas[0] } }
  end

  def test_too_short
    delta3d = Delta3D.new( JSON.generate( { "txt" => File.read('fixtures/too_short.txt') } ) )
    exception = assert_raise( StandardError ) do
      delta3d.calculate
    end
    assert_equal "The length of the uploaded text is too short for analysis.", exception.message
  end

end
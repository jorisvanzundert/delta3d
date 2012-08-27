require 'rubygems'
require 'json/pure'
require 'logger'

class Delta3D

  def initialize( json_string )
    File.open( "delta3d.log", "a" )
    @logger = Logger.new('delta3d.log', 10, 1024000)
    
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
    
    raise InvalidJSONStructureException, "JSON input does not have the right structure" if source.size != 1
    first_key = source.keys.first 
    raise InvalidJSONStructureException, "JSON input does not have the right structure" if !["txt", "l", "p", "lines", "positions"].include? first_key
    self.send( first_key, source[ first_key ] )
  end
   
  def txt( txt_source )
    position_id = 0
    positions_source = txt_source.split.map do |surface|
      { "id" => "#{position_id+=1}" , "t" => { "s" => surface } }
    end
    positions( positions_source )
  end
   
  def positions( positions_source )
    tokens = positions_source.collect { |position| Token.new( position ) }
    tokens = tokens.sort{ |token_a, token_b| token_a.position <=> token_b.position }
    tokens_for_line = Array.new
    @lines_ordered = Array.new
    tokens.each_with_index do |token, index|
      tokens_for_line.push( token )
      if (index+1).modulo(5) == 0
        @lines_ordered.push( LineFromTokens.new( ((index+1)/5), tokens_for_line ) )
        tokens_for_line = Array.new
      end
    end
    @lines_ordered.push( LineFromTokens.new( @lines_ordered.size+1, tokens_for_line ) ) if tokens_for_line.size != 0
  end

  alias :p :positions
  
  def lines( lines_source )
    lines_unordered = convert( lines_source )
    @lines_ordered = lines_unordered.sort{ |line_a,line_b| line_a.line_id <=> line_b.line_id }
  end

  alias :l :lines
  
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
  
  def calculate( options={} )
    options = { :window_size => 1000, :spectrum_size => 50, :spectrum_shift => 10, :shifts => 10, :sample => 100}.merge(options)
    step = Time.now
    plot_data = []
    guard_size( lines_ordered )
    background = BackgroundFactory.create( lines_ordered, lines_ordered.size / 1000 )
    bias = Bias.new( background, lines_ordered, options[:bias_start], options[:bias_end] )
    walking_window = Window.new( lines_ordered, options[:window_size] )
    options[:shifts].times do |shift|
      spectrum_start = shift*options[:spectrum_shift]
      lemma_stats = background.top(spectrum_start,options[:spectrum_size])
      window_count = zsum = frequency = zscore = 0
      walking_window.each do |window|
        if window_count.modulo(options[:sample]) == 0
          zsum = lemma_stats.inject( 0 ) do |zsum, lemma_stat|
            frequency = window.frequencies[lemma_stat.lemma]
            if !frequency.nil?
              zscore = ( (frequency.to_f/window.lemma_count) - lemma_stat.mean_freq ) / lemma_stat.stdev
            else
              zscore = ( -lemma_stat.mean_freq ) / lemma_stat.stdev
            end
            zsum += (bias.zscore(lemma_stat.lemma) - zscore).abs
          end
          data_point = [window_count + (options[:window_size]/2), zsum/options[:spectrum_size] , spectrum_start ,"#{spectrum_start}-#{spectrum_start+options[:spectrum_size]}"]
          plot_data.push( data_point )
        end
        window_count += 1
      end
      duration = Time.now - step
      @logger.info "Walked window (top: #{spectrum_start}-#{(spectrum_start)+options[:spectrum_size]}), duration: #{duration}."
      step = Time.now
    end
    plot_data
  end

  def plot( plot_data )
    path = File.expand_path(File.dirname(__FILE__))
    Dir.entries("#{path}/tmp/").reject!{ |f| !f.split("/").last.include?("delta3d") }.each{|f| File.delete( File.join("#{path}/tmp/", f) ) }
    tmp_suffix = Time.now.strftime("%Y%m%d%H%M%S")
    data_file = "#{path}/tmp/delta3d_plot_data_#{tmp_suffix}.gp"
    plot_data_file = File.new( data_file, 'w')
    plot_data_string = ""
    plot_data.inject(0) do |memo, data_point|
      plot_data_string << "\n\n" if memo < data_point[2] 
      plot_data_string << "#{data_point[0]}\t#{data_point[2]}\t#{data_point[1]}\t#{data_point[3]}\n"
      memo = data_point[2]
    end
    plot_data_file.write( plot_data_string )
    plot_data_file.close
    plot_data_string = %{<?xml version="1.0" encoding="utf-8"  standalone="no"?>\n<pre>} << plot_data_string << "</pre>\n"
    gn = %{set xlabel "line" font "Times New Roman Bold, 11" offset 0,-1
set ylabel "top f segment" font "Times New Roman Bold, 11" offset -0.5,-1
set zlabel "Delta" font "Times New Roman Bold, 11" offset 5,0
set terminal svg font "Times New Roman, 8"
set nokey
set style line 1 lw 1 pt 6 palette
set style line 2 lc rgbcolor "#aaaaaa"
set bmargin 0.1
set xtics 2000
set xtics offset 0,-0.5
set ytics offset 1.0,-0.2
}
    svg_views = [[70,15],[20,0],[90,90],[90,0]]
    svg_views.each do |view|
      gn << %{set output
set view #{view[0]}, #{view[1]}
splot "#{data_file}" using 1:2:3:ytic(4) with lines ls 1
}
    end
    gn_file_name = "#{path}/tmp/delta3d_gn_file_#{tmp_suffix}.gp"
    gn_file = File.new( gn_file_name, 'w')
    gn_file.write( gn )
    gn_file.close
    svgs = `gnuplot #{gn_file_name}`
    raise "GNU plot execution failed (is it installed and in your PATH?)" if !$?.to_i.eql?(0)
    svgs << plot_data_string
  end

  def guard_size( lines_ordered )
    raise StandardError, "The length of the uploaded text is too short for analysis." if lines_ordered.size < 2000
  end
  
end


class Background
  
  def initialize( lemma_stats )
    @stats = lemma_stats.sort { |lemma_a, lemma_b| lemma_b.mean_freq<=>lemma_a.mean_freq } 
  end
  
  def all
    @stats
  end
  
  def top( start, n )
    @stats[start,n]
  end
  
  def get( lemma )
    @stats.detect{ |lemma_stat| lemma_stat.lemma.eql?(lemma) }
  end
  
  def size
    @stats.size
  end
  
end


class LemmaStat
  
  def initialize( lemma, mean_freq, stdev )
    @lemma = lemma
    @mean_freq = mean_freq
    @stdev = stdev
  end
  
  def lemma
    @lemma
  end
  
  def mean_freq
    @mean_freq
  end
  
  def stdev
    @stdev
  end
  
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
    lemma_stats = Array.new
    frequencies.each do |lemma, part_frequencies|
      part_frequencies.each_index { |part| part_frequencies[part] = part_frequencies[part].to_f/lemma_counts[part].to_f}
      mean_freq = ( part_frequencies.inject(0) { |sum,f| sum + f } ) / parts
      stdev = Math.sqrt( ( part_frequencies.inject(0) { |stdevsum,f| stdevsum +  (f-mean_freq)**2 } ) / parts )
      lemma_stats.push( LemmaStat.new( lemma, mean_freq, stdev ) )
    end
    Background.new( lemma_stats )
  end

end


class Window
  
  def initialize( ordered_lines, window_size )
    @window_size = window_size
    @lines = ordered_lines
    reset
  end
  
  def reset
    @lemma_count = 0
    @frequencies = Hash.new
    @lines[0, @window_size].each do |line|
      add_frequencies( line )
    end
    @lines_to_walk = @lines[@window_size, @lines.length]
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
        !@frequencies.include?( lemma ) ? @frequencies[lemma] = 1 : @frequencies[lemma] += 1
        @lemma_count += 1
      end
    end
  end

  def remove_frequencies( line )
    line.tokens.each do |token|
      token.lemmas.each do |lemma|
        @frequencies[lemma] -= 1
        frequencies.delete(lemma) if frequencies[lemma] == 0
        @lemma_count -= 1
      end
    end
  end
  
  def each(&block)
    @lines_to_walk.each_with_index do |line,index|
      yield self
      add_frequencies( line )
      remove_frequencies( @lines[index] )
    end
    yield self
    reset
  end
  
end


class Line
  
  def initialize( line_source )
    guard_invalid if !line_source.is_a? Hash
    guard_invalid if line_source["id"].nil?
    positions_key = line_source.has_key?("positions") ? "positions" : "p"
    guard_invalid if line_source[positions_key].nil?
    @line_id = Integer( line_source["id"] )
    @tokens = line_source[positions_key].collect { |position| Token.new( position ) }
  end

  def guard_invalid
    raise InvalidJSONStructureException, "JSON input does not have the right structure" 
  end
  
  def line_id
    @line_id
  end
  
  def tokens
    @tokens
  end
  
end


class LineFromTokens < Line
  
  def initialize( line_id, tokens )
    @tokens = tokens
    @line_id = line_id
  end
  
end  


class Token

  def initialize( token_source )
    guard_invalid if !token_source.is_a? Hash
    guard_invalid if token_source.size > 2
    guard_invalid if token_source["id"].nil?
    token_key = token_source.has_key?("token") ? "token" : "t"
    guard_invalid if token_source[token_key].nil?
    surface_key = token_source[token_key].has_key?("surface") ? "surface" : "s"
    guard_invalid if token_source[token_key][surface_key].nil?
    @position = Integer( token_source["id"] )
    @surface = token_source[token_key][surface_key]
    lemmas_key = token_source[token_key].has_key?("lemmas") ? "lemmas" : "l"
    @lemmas = token_source[token_key][lemmas_key]
    @lemmas = [@surface] if @lemmas.nil?
  end

  def guard_invalid
    raise InvalidJSONStructureException, "JSON input does not have the right structure" 
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


class Bias
  
  def initialize( background, ordered_lines, bias_start, bias_end )
    if bias_end > 0
      raise StandardError, "Invalid bias parameters" if bias_end < bias_start
      raise StandardError, "Invalid bias parameters" if bias_end > ordered_lines.size || bias_start > ordered_lines.size
      lemma_count = 0
      frequencies = Hash.new
      ordered_lines[bias_start..bias_end].each do |line|
        line.tokens.each do |token|
          token.lemmas.each do |lemma|
            !frequencies.include?( lemma ) ? frequencies[lemma] = 1 : frequencies[lemma] += 1
            lemma_count += 1
          end
        end
      end
      @zscores = background.all.inject({}) do |zscores, lemma_stat|
        frequency = frequencies[lemma_stat.lemma]
        if !frequency.nil?
          zscores[lemma_stat.lemma] = ( (frequency.to_f/lemma_count) - lemma_stat.mean_freq ) / lemma_stat.stdev
        else
          zscores[lemma_stat.lemma] = ( -lemma_stat.mean_freq ) / lemma_stat.stdev
        end
        zscores
      end
    end
  end

  def zscore( lemma )
    @zscores.nil? ? 0 : @zscores[lemma]
  end

end


class InvalidJSONStructureException < StandardError
end

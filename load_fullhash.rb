require 'json/pure'
require 'gnuplot'

# { line: { position: { token: [ lemma1, lemma2, ...] } }

class TextHash

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
  
  def create_background(n)
    quotient = ( max_position.to_f / n.to_f ).ceil
    lemmas_in_quotients = Array.new(n,0)
    background = @text_hash.values.inject(Hash.new) do |base, line| 
      line.each do |position, token_lemmas|
        token_lemmas.values[0].each do |lemma|
          base[lemma] = Array.new(n,0) if !base.include?( lemma )
          index = (((Integer(position))-1)/quotient).floor
          if !(index>=n)
            base[lemma][index] += 1 if 
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
  
  def each_window(&block)
    text_hash_ordered_by_line = @text_hash.sort { |line_a, line_b| Integer( line_a[0] ) <=> Integer( line_b[0] ) }
    current_line = 0
    window_size = 1000
    window = Array.new
    window_frequencies = Hash.new
    lemma_count = 0
    text_hash_ordered_by_line.each do |line|
      #[ line, [ position, [token, [lemma, lemma ] ] ], line.. ]
      line[1].each do |position|
        position[1].values[0].each do |lemma|
          !window_frequencies.include?( lemma ) ? window_frequencies[lemma] = 1 : window_frequencies[lemma] += 1
          lemma_count += 1
        end
      end
      window.push(line)
      if window.size == window_size
        current_line += 1
        yield window_frequencies, lemma_count, current_line
        window.slice!(0)[1].each do |position|
          position[1].values[0].each do |lemma|
            window_frequencies[lemma] -= 1
            window_frequencies.delete(lemma) if window_frequencies[lemma] == 0
            lemma_count -= 1
          end
        end
      end
    end
  end

end

start = Time.now
step = Time.now
puts "Loading JSON"
text_hash = TextHash.new( File.new('testsources/full_hash.json') )
puts "#{text_hash.line_size} lines allocated"
puts "#{text_hash.token_size} tokens read"
puts "#{text_hash.lemma_size} lemmas filed"
duration = Time.now - step
puts "time: #{duration}"
step = Time.now
puts "Creating background"
background = text_hash.create_background(10)
background = background.sort { |lemma_a, lemma_b| lemma_b[1][0]<=>lemma_a[1][0]}
duration = Time.now - step
puts "time: #{duration}"
step = Time.now
plot_data = []
n = 0
10.times do
  top_f = background[n,50]
  puts "Walking window (top: #{n}-#{n+50})"
  text_hash.each_window do |window_frequencies, lemma_count, current_line|
    if current_line.modulo(100) == 0
      zsum = top_f.inject( 0 ) do |zsum, lemma_background|
        if window_frequencies.include?( lemma_background[0] )
          zscore = ( (window_frequencies[lemma_background[0]].to_f/lemma_count) - lemma_background[1][0] ) / lemma_background[1][0]
        else
          zscore = ( -lemma_background[1][0] ) / lemma_background[1][0]
        end
        zsum += zscore.abs
      end
      data_point = [current_line + 500,zsum/50,n,"#{n}-#{n+50}"]
      plot_data.push( data_point )
    end
  end
  n+=10
  duration = Time.now - step
  puts "time: #{duration}"
  step = Time.now
end
puts "Writing plot data"
# Gnuplot.open do |gp|
#   Gnuplot::SPlot.new( gp ) do |plot|
#     plot.terminal 'png'
#     filepath = File.expand_path('../testsources/full_hash.png', __FILE__)
#     plot.output "'#{filepath}'"
#     plot.title "Windowed Delta (1000 lines, top 1-50f)"
#     plot.xlabel "verse"
#     plot.ylabel "Delta"
#     plot.data << Gnuplot::DataSet.new( [[1,2,3],[1.5,2.0,2.5],[1,2,3]] ) do |ds|
#       ds.with = "points"
#       ds.notitle
#     end
#     puts plot.data.inspect
#   end
# end

plot_file = File.new( 'testsources/plot_data.txt', 'w')
plot_data.inject(0) do |memo, data_point|
  plot_file.write( "\n\n" ) if memo < data_point[2] 
  plot_file.write( "#{data_point[0]}\t#{data_point[2]}\t#{data_point[1]}\t#{data_point[3]}\n")
  memo = data_point[2]
end
duration = Time.now - step
puts "time: #{duration}"
puts "Done"
duration = Time.now - start
puts "(total time: #{duration})"
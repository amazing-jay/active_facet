#TODO - move this file into its own gem
require "benchmark"

class WatchfulGuerilla
	def self.toggle_tracing(state = true)
		@trace_enabled = !!state
	end

	def self.toggle_profiling(state = true)
		@profile_enabled = !!state
	end

  def self.toggle_measuring(state = true)
    @measure_enabled = !!state
  end

	def self.reporting_threshold(milliseconds = 20)
		@reporting_threshold = milliseconds / 1000.0
	end

	toggle_tracing false
	toggle_profiling false
	toggle_measuring !!ENV['MEASURE']
  reporting_threshold

  def self.profile(printer = :graph, profile_name = 'profile', profile_options = {})
  	return yield unless @profile_enabled
    profile = nil
    result = nil
    begin
    	@profile_active = true
      RubyProf.start
      result = yield
    ensure
      profile = RubyProf.stop
      @profile_active = false
    end

    case printer
    when :graph
        RubyProf::GraphPrinter.new(profile).print(
          File.open("#{Rails.root}/tmp/#{profile_name}-graph.html", 'w+'),
          {print_file:true, min_percent: 1}.merge(profile_options)
        )
    when :flat
        RubyProf::FlatPrinter.new(profile).print(
          File.open("#{Rails.root}/tmp/#{profile_name}-flat.html", 'w+')
        )
    end

    result
  end

  def self.pause
  	RubyProf.pause if @profile_enabled && @profile_active
  end

  def self.resume
		RubyProf.resume if @profile_enabled && @profile_active
  end

  def self.print_measured_results
    total_time, total_overhead_time = 0, 0
    ap "---- Time in Category -- Overhead Time -- Category"
  	@category_times.sort_by{|k,v| v}.reverse.each do |category, p_time|
      o_time = @category_overhead_times[category]
      total_time += p_time
      total_overhead_time += o_time
      p_time_s = format("%.3f", p_time*1000).rjust(16,' ')
      o_time_s = format("%.3f", o_time*1000).rjust(13,' ')
  		ap "---- #{p_time_s} -- #{o_time_s} -- #{category}"
  	end
    p_time_s = format("%.3f", total_time*1000).rjust(16,' ')
    o_time_s = format("%.3f", total_overhead_time*1000).rjust(13,' ')
    ap "---- #{p_time_s} -- #{o_time_s} -- TOTALS"
    ap ""
    ap "LONG CALLS"
    @long_calls.sort_by{|v| v[1]}.reverse.each do |(category, p_time)|
      p_time_s = format("%.3f", p_time*1000).rjust(16,' ')
      ap "---- #{p_time_s} >> #{category}"
    end
  end

  def self.check_root(node)
  	@root == node
  end

  def self.increment_category_time(node)
    @category_times[node.category] = (@category_times[node.category] || 0) + node.pure_time
  	@category_overhead_times[node.category] = (@category_overhead_times[node.category] || 0) + node.overhead_time
    @long_calls << [node.identifier, node.pure_time] if node.pure_time > @reporting_threshold
  end

  def self.measure(category = '*unspecified*', *identifiers)
  	return yield unless @measure_enabled
  	result = nil
  	current = nil
  	overhead_time = Benchmark.realtime {
			ap "--***#{@i}***--#{category}:: #{identifiers}" if @trace_enabled
			old_top = @top
			@top = current = new(category, identifiers)
	  	if @root
	  		old_top.children << @top
	  	else
        @category_times = {}
	  		@category_overhead_times = {}
        @long_calls = []
	  		@root = @top
	  	end
			result = @top.measure Proc.new
			@top = old_top
			unless @top
				print_measured_results
				@root = nil
			end
		}
		@top.overhead_time += overhead_time - current.total_time if @top.present?
    raise current.exception if current.exception.present?
		result
  end

  attr_accessor :total_time, :child_time, :self_time, :overhead_time, :pure_time, :children, :category, :identifiers, :exception

  def initialize(category, identifiers = [])
    self.identifiers = identifiers
  	self.category = category
  	self.children = []
  	self.overhead_time = 0
  end

  def measure(block)
  	result = nil
  	self.total_time = Benchmark.realtime do
      begin
        result = block.call
      rescue => e
        self.exception = e
      end
    end
  	self.child_time = children.map(&:total_time).sum
  	self.self_time = total_time - child_time
  	self.pure_time = self_time - overhead_time
  	increment_category_time
  	result
  end

  def increment_category_time
  	self.class.increment_category_time self
  end

  def identifier
    @identifier ||= ([category] + identifiers).join(', ')
  end

  # def is_root?
  # 	self.class.check_root(self)
  # end

  # def print_measured_results
  # 	self.print_measured_results
  # end
end

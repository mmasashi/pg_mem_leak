# Script for reproducing a memory leak issue
# How to use:
#   Edit postgresql db config
#   Run "bundle install"
#   Run "bundle exec ruby mem_leak.rb <pattern-no(1-12) (required)> <num_exec(default: 10) (optional)>"
#
# This scirpt loops the following steps every 5 seconds
# - Run a select query (Only first num_exec(default: 10) iterations)
# - Call GC.start
# - Sleep 5 seconds
#
# After the number of query counts reach the num_exec(default: 10), running a query will be skipped.
# Instead, it will call only GC.start with sleep to check if the memory usage is going down.
#
# See run_once method about the patterns.
#
# Examples:
#
# (1) Leak pattern - Memory does not go down
# $ bundle exec ruby mem_leak.rb 2 3
# mem: 0.1%
# ---- pattern:2 cnt:1/3 running query and start GC
# mem: 0.9%
# mem: 0.9%
# ---- pattern:2 cnt:2/3 running query and start GC
# mem: 1.2%
# mem: 1.2%
# ---- pattern:2 cnt:3/3 running query and start GC
# mem: 1.5%
# mem: 1.5%
# ---- cnt:4/3 starts only GC
# mem: 1.5%
# mem: 1.5%
# ---- cnt:5/3 starts only GC
# mem: 1.5%
# mem: 1.5%
# ---- cnt:6/3 starts only GC
# mem: 1.5%
# mem: 1.5%
#
# (2) No leak pattern - Memory goes down
# ruby mem_leak.rb 3 3
# mem: 0.1%
# ---- pattern:3 cnt:1/3 running query and start GC
# mem: 0.8%
# mem: 0.8%
# ---- pattern:3 cnt:2/3 running query and start GC
# mem: 1.0%
# mem: 1.0%
# ---- pattern:3 cnt:3/3 running query and start GC
# mem: 1.1%
# mem: 1.1%
# ---- cnt:4/3 starts only GC
# mem: 1.0%
# mem: 1.0%
# ---- cnt:5/3 starts only GC
# mem: 1.0%
# mem: 1.0%
# ---- cnt:6/3 starts only GC
# mem: 0.9%
# mem: 0.9%

require 'pg'
require 'pry'
require_relative 'config'

def h_to_s(hash)
  hash.collect do |k, v|
    "#{k}:#{v}"
  end.join(' ')
end

def show_gc_stat
  mem = `ps u -p #{Process.pid}|tail -n 1|awk '{print $4}'`.strip
  #puts("[#{Time.now.strftime("%Y%m%d %H:%M:%S")}] #{h_to_s(GC.stat.merge(mem: mem))}")
  #puts("#{h_to_s(GC.stat.merge(mem: mem))}")
  #puts("  -> #{h_to_s(ObjectSpace.count_objects.select{|k,v| %w(TOTAL FREE T_STRING T_ARRAY T_HASH T_DATA).include?(k.to_s)}.merge(mem: mem)).downcase}")
  #puts("#{h_to_s(ObjectSpace.count_objects.merge(mem: mem)).downcase}")
  puts("mem: #{mem}%")
end

TEST_QUERY = "SELECT * FROM #{TEST_PG_MEM_LEAK_TABLE_NAME} LIMIT 50000"
def run_once(pattern)
  ary = []

  conn = PGconn.open(PG_DB_CONFIG)
  if pattern.to_i < 14
    result = conn.exec(TEST_QUERY)
  end

  case pattern.to_s
  when '0'   # leak - originaly I wanted to do like this
    result.each do |record| # call result.each but do nothing inside block
        ary << record.values
    end
  when '1'   # no leak
    result.each do |record| # call result.each but do nothing inside block
    end
  when '2'   # leak
    result.each do |record|
      ary << {}             # push empty hash inside result.each block
    end
  when '3'   # no leak
    1.upto(50000) do
      ary << {}             # push empty hash inside 1.upto(50000) block
    end
  when '4'   # no leak
    result.each do |record|
      ary << nil            # push nil inside result.each block
    end
  when '5'   # leak
    1.upto(50000) do |i|
      ary << result[i-1]    # push result with index access inside 1.upto(5000) block
    end
  when '6'   # leak
    result.each do |record|
      ary << 'aaaaaaaaaa'   # push created string inside result.each block
    end
  when '7'   # no leak
    result.each do |record|
      ary << :aaaaaaaaaa    # push symbol inside result.each block
    end
  when '8'   # no leak
    result.each do |record|
      {}                    # create empty hash inside result.each block
    end
  when '9'   # leak
    result.each do |record|
      ary << {}             # push empty hash but return nil inside result.each block
      nil
    end
  when '10'  # no leak
    result.each do |record|
      tmp = []
      tmp << {}             # create empty array and push empty hash into it inside result.each block
      nil
    end
  when '11'   # leak
    result.each do |record|
      ary << {}             # push empty hash inside result.each block
    end
    ary.clear
  when '12'   # slow leak
    1.upto(50000) { ary << {} } # push empty hash outside result.each block
    result.each do |record|
    end
  when '13'   # leak
    result.each do |record|
      ary << {}
    end
    result.clear   # call clear
  when '14'   # no leak! This would be a workaround
    conn.exec(TEST_QUERY) do |result|
      ary << {}
    end
  when '15'   # leak
    conn.exec(TEST_QUERY) do |result|
      ary << result.values
    end
  when '16'   # no leak
    1.upto(50000) do |i|
      ary << [i, 'aaaaaaaaaa' * 1000]
    end
  when ''     # no leak
    # Do nothing
  else
    raise "Unsupported pattern"
  end
  nil
ensure
  conn.close if conn
  conn = nil
end

def run_loop(pattern = nil, num_exec = 10)
  cnt = 1
  loop do
    show_gc_stat
    if cnt <= num_exec
      puts "---- pattern:#{pattern} cnt:#{cnt}/#{num_exec} running query and start GC"
      run_once(pattern)
    else
      puts "---- pattern:#{pattern} cnt:#{cnt}/#{num_exec} starts only GC"
    end
    GC.start
    show_gc_stat
    sleep 5
    cnt += 1
  end
end

pattern = ARGV[0]
# Number of iterations for running queries
# For example, by giving 5, this runs a query 5 times with GC, then start runnning only GC every 5 seconds
num_exec = ARGV[1] ? ARGV[1].to_i : 10
run_loop(pattern, num_exec)

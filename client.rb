require 'openssl'
require 'faraday'
require 'async'
require 'async/barrier'
require 'async/semaphore'


OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

class TimeIsOverError < StandardError; end

class ResultIsNotEq < StandardError; end

expected_result = "0bbe9ecf251ef4131dd43e1600742cfb"

expected_time = 7

# Есть три типа эндпоинтов API
# Тип A:
#   - работает 1 секунду
#   - одновременно можно запускать не более трёх
# Тип B:
#   - работает 2 секунды
#   - одновременно можно запускать не более двух
# Тип C:
#   - работает 1 секунду
#   - одновременно можно запускать не более одного
#
def a(value)
  Thread.new do
    puts "https://localhost:9292/a?value=#{value}"
    Faraday.get("https://localhost:9292/a?value=#{value}").body
  end  
end

def b(value)
  Thread.new do
    puts "https://localhost:9292/b?value=#{value}"
    Faraday.get("https://localhost:9292/b?value=#{value}").body
  end
end

def c(value)
  Thread.new do
    puts "https://localhost:9292/c?value=#{value}"
    Faraday.get("https://localhost:9292/c?value=#{value}").body
  end
end

func_a = proc { |v| a(v) }
func_b = proc { |v| b(v) }
func_c = proc { |v| c(v) }

@result_task_a = []

def start_worker(values, worker, count, result)
  barrier = Async::Barrier.new
  Async do
    semaphore = Async::Semaphore.new(count, parent: barrier)
    values.map do |value|
      semaphore.async do
        result[value] = worker.call(value).value       
      end
    end.map(&:wait)
    ensure
      barrier.stop
    end
end

# Референсное решение, приведённое ниже работает правильно, занимает ~19.5 секунд
# Надо сделать в пределах 7 секунд

def collect_sorted(arr)
  arr.sort.join('-')
end

val1 = [11, 12, 13]
val2 = [21, 22, 23]
val3 = [31, 32, 33]

@all_vall_a = [val1, val2, val3]
@all_vall_b = [1, 2, 3]

@results_task_a = {}
@results_task_b = {}
@results_task_c = {}

@threads = []

@threads << Thread.new {
  @all_vall_a.each do |v|
    start_worker(v, func_a, 3, @results_task_a)
  end
}
@threads << Thread.new { start_worker(@all_vall_b, func_b ,2, @results_task_b) }

@threads << Thread.new do
  index_fetch = 0
  exists = []
  process = true
  while process do
    keys = @results_task_b.keys
    unless keys.empty?
      keys.each do |key|
        next if exists.include?(key)
        if key == 1
          if @results_task_a[11] && @results_task_a[12] && @results_task_a[13]
            payload = "#{[@results_task_a[11], @results_task_a[12], @results_task_a[13]].sort.join("-")}-#{@results_task_b[key]}"
            start_worker([payload], func_c ,1, @results_task_c)
            exists << key
            index_fetch += 1
          end
        elsif key == 2
          if @results_task_a[21] && @results_task_a[22] && @results_task_a[23]
            payload = "#{[@results_task_a[21], @results_task_a[22], @results_task_a[23]].sort.join("-")}-#{@results_task_b[key]}"
            start_worker([payload], func_c ,1, @results_task_c)
            exists << key
            index_fetch += 1
          end
        elsif key == 3
          if @results_task_a[31] && @results_task_a[32] && @results_task_a[33]
            payload = "#{[@results_task_a[31], @results_task_a[32], @results_task_a[33]].sort.join("-")}-#{@results_task_b[key]}"
            start_worker([payload], func_c ,1, @results_task_c)
            exists << key
            index_fetch += 1
          end
        end
      end
    end
    if index_fetch >= 3
      process = false 
      break  
    end
  end
end
start = Time.now
@threads.map(&:join)

result = a(@results_task_c.values.sort.join("-")).value
# ab1 = start_worker(val1, 1, func_a, func_b)
# # puts "AB1 = #{ab1}"

# c1 = c(ab1)
# # puts "C1 = #{c1}"

# # val = [21, 22, 23]

# ab2 = start_worker(val2, 2, func_a, func_b)
# # puts "AB2 = #{ab2}"

# c2 = c(ab2)
# # puts "C2 = #{c2}"

# # val = [31, 32, 33]

# ab3 = start_worker(val3, 3, func_a, func_b)
# # puts "AB3 = #{ab3}"

# c3 = c(ab3)
# # puts "C3 = #{c3}"

# c123 = collect_sorted([c1, c2, c3])
# result = a(c123)


time = Time.now - start

puts "FINISHED in #{time}s."
puts "RESULT = #{result}" # 0bbe9ecf251ef4131dd43e1600742cfb

if result != expected_result
  raise ResultIsNotEq, "#{result} != #{expected_result}"
end

# if time > expected_time
#   raise TimeIsOverError, "#{time}"
# end

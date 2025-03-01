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
  puts "https://localhost:9292/a?value=#{value}"
  Faraday.get("https://localhost:9292/a?value=#{value}").body
end

def b(value)
  puts "https://localhost:9292/b?value=#{value}"
  Faraday.get("https://localhost:9292/b?value=#{value}").body
end

def c(value)
  puts "https://localhost:9292/c?value=#{value}"
  Faraday.get("https://localhost:9292/c?value=#{value}").body
end

func_a = proc { |v| a(v) }
func_b = proc { |v| b(v) }
func_c = proc { |v| c(v) }

@result_task_a = []

def start_worker(values_a,  value_b, worker_a, worker_b, worker_c)
  barrier = Async::Barrier.new
  @results_a = []
  @result_b = ""
  threads = []
  Sync do
    semaphore = Async::Semaphore.new(4, parent: barrier)
    values_a.each do |value|
      threads << semaphore.async do
        @results_a << worker_a.call(value)       
      end
    end
    threads << semaphore.async do
      @result_b = worker_b.call(value_b)
    end
    threads.map(&:wait)
    ensure
      barrier.stop
    end
  result_ab = "#{@results_a.sort.join('-')}-#{@result_b}"
  worker_c.call(result_ab)
end

# Референсное решение, приведённое ниже работает правильно, занимает ~19.5 секунд
# Надо сделать в пределах 7 секунд

def collect_sorted(arr)
  arr.sort.join('-')
end

start = Time.now



ab1 = start_worker(val, 1, func_a, func_b)
puts "AB1 = #{ab1}"

c1 = c(ab1)
puts "C1 = #{c1}"

val = [21, 22, 23]

ab2 = start_worker(val, 2, func_a, func_b)
puts "AB2 = #{ab2}"

c2 = c(ab2)
puts "C2 = #{c2}"

val = [31, 32, 33]

ab3 = start_worker(val, 3, func_a, func_b)
puts "AB3 = #{ab3}"

c3 = c(ab3)
puts "C3 = #{c3}"

c123 = collect_sorted([c1, c2, c3])
result = a(c123)


time = Time.now - start

puts "FINISHED in #{time}s."
puts "RESULT = #{result}" # 0bbe9ecf251ef4131dd43e1600742cfb

if result != expected_result
  raise ResultIsNotEq, "#{result} != #{expected_result}"
end

if time > expected_time
  raise TimeIsOverError, "#{time}"
end

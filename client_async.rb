require 'openssl'
require 'faraday'
require 'async'
require 'async/barrier'
require 'async/semaphore'

OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

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

# Референсное решение, приведённое ниже работает правильно, занимает ~19.5 секунд
# Надо сделать в пределах 7 секунд

def collect_sorted(arr)
  arr.sort.join('-')
end

start = Time.now

barrier = Async::Barrier.new

a_semaphore = Async::Semaphore.new(3, parent: barrier)
b_semaphore = Async::Semaphore.new(2, parent: barrier)
c_semaphore = Async::Semaphore.new(1, parent: barrier)

as = []
bs = []

# 2s
Async do
  [1, 2].each do |i|
    b_semaphore.async(parent: barrier) do
      bs << b(i)
    end
  end

  [11, 12, 13, 21, 22, 23].each do |i|
    a_semaphore.async(parent: barrier) do
      as << a(i)
    end
  end

  # Wait until all jobs are done:
  barrier.wait
end

ab1 = "#{collect_sorted(as[0,3])}-#{bs[0]}"
puts "AB1 = #{ab1}"

ab2 = "#{collect_sorted(as[3,3])}-#{bs[1]}"
puts "AB2 = #{ab2}"

as = []
b3 = nil
c1 = nil
c2 = nil

# 2s
Async do
  b_semaphore.async(parent: barrier) do
    b3 = b(3)
  end

  [31, 32, 33].each do |i|
    a_semaphore.async(parent: barrier) do
      as << a(i)
    end
  end

  c_semaphore.async(parent: barrier) do
    c1 = c(ab1)
    c2 = c(ab2)
  end
  # Wait until all jobs are done:
  barrier.wait
end

puts "C1 = #{c1}"
puts "C2 = #{c2}"
ab3 = "#{collect_sorted(as)}-#{b3}"
puts "AB3 = #{ab3}"

# 1s
c3 = c(ab3)
puts "C3 = #{c3}"

c123 = collect_sorted([c1, c2, c3])
# 1s
result = a(c123)

puts "FINISHED in #{Time.now - start}s."
puts "RESULT = #{result}" # 0bbe9ecf251ef4131dd43e1600742cfb

require 'openssl'
require 'faraday'

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

# 3*a + 2*b (2s)
as = []
bs = []

a_threads = []
b_threads = []

[11, 12, 13].each do |i|
  a_threads << Thread.new { as << a(i) }
end

[1, 2].each do |i|
  b_threads << Thread.new { bs << b(i) }
end

# Ждем  a(11), a(12), a(13)
a_threads.each(&:join)

# Запускаем a(21), a(22), a(23) после завершения a(11), a(12), a(13)
[21, 22, 23].each do |i|
  b_threads << Thread.new { as << a(i) }
end

# Ждем завершения всех потоков
b_threads.each(&:join) # 2s

ab1 = "#{collect_sorted(as[0,3])}-#{bs[0]}"
puts "AB1 = #{ab1}"

ab2 = "#{collect_sorted(as[3,3])}-#{bs[1]}"
puts "AB2 = #{ab2}"

as = []
b3 = nil
c1 = nil
c2 = nil

ab_threads = []

[31, 32, 33].each do |i|
  ab_threads << Thread.new { as << a(i) }
end

ab_threads << Thread.new { b3 = b(3) }

Thread.new { c1 = c(ab1) }.join
Thread.new { c2 = c(ab2) }.join

ab_threads.each(&:join) # 2s

puts "C1 = #{c1}"

ab3 = "#{collect_sorted(as)}-#{b3}"
puts "AB3 = #{ab3}"

puts "C2 = #{c2}"

# 1s
c3 = c(ab3)
puts "C3 = #{c3}"

c123 = collect_sorted([c1, c2, c3])
result = a(c123) # 1s

puts "FINISHED in #{Time.now - start}s."
puts "RESULT = #{result}" # 0bbe9ecf251ef4131dd43e1600742cfb

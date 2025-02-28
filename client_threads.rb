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
res = [Thread.new { a(11) }, Thread.new { a(12) }, Thread.new { a(13) }, Thread.new { b(1) }, Thread.new { b(2) }].map(&:value)
b2 = res.pop
b1 = res.pop

ab1 = "#{collect_sorted(res)}-#{b1}"
puts "AB1 = #{ab1}"

# 3*a + b + c (2s)
res = [Thread.new { a(21) }, Thread.new { a(22) }, Thread.new { a(23) }, Thread.new { b(3) }, Thread.new { c(ab1) }].map(&:value)
c1 = res.pop
puts "C1 = #{c1}"
b3 = res.pop


ab2 = "#{collect_sorted(res)}-#{b2}"
puts "AB2 = #{ab2}"

# 3*a + c (1s)
res = [Thread.new { a(31) }, Thread.new { a(32) }, Thread.new { a(33) }, Thread.new { c(ab2) }].map(&:value)
c2 = res.pop
puts "C2 = #{c2}"

ab3 = "#{collect_sorted(res)}-#{b3}"
puts "AB3 = #{ab3}"

# 1s
c3 = c(ab3)
puts "C3 = #{c3}"

c123 = collect_sorted([c1, c2, c3])
# 1s
result = a(c123)

puts "FINISHED in #{Time.now - start}s."
puts "RESULT = #{result}" # 0bbe9ecf251ef4131dd43e1600742cfb

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

result = Sync do
  semaphore_a = Async::Semaphore.new(3)
  semaphore_b = Async::Semaphore.new(2)
  semaphore_c = Async::Semaphore.new(1)

  ab1 = Async do
    b1 = semaphore_b.async{ b(1) }
    a11 = semaphore_a.async{ a(11) }
    a12 = semaphore_a.async{ a(12) }
    a13 = semaphore_a.async{ a(13) }

    "#{collect_sorted([a11.wait, a12.wait, a13.wait])}-#{b1.wait}"
  end

  ab2 = Async do
    b2 = semaphore_b.async{ b(2) }
    a21 = semaphore_a.async{ a(21) }
    a22 = semaphore_a.async{ a(22) }
    a23 = semaphore_a.async{ a(23) }

    "#{collect_sorted([a21.wait, a22.wait, a23.wait])}-#{b2.wait}"
  end

  ab3 = Async do
    b3 = semaphore_b.async{ b(3) }
    a31 = semaphore_a.async{ a(31) }
    a32 = semaphore_a.async{ a(32) }
    a33 = semaphore_a.async{ a(33) }

    "#{collect_sorted([a31.wait, a32.wait, a33.wait])}-#{b3.wait}"
  end

  c1 = semaphore_c.async { c(ab1.wait) }
  c2 = semaphore_c.async { c(ab2.wait) }
  c3 = semaphore_c.async { c(ab3.wait) }

  c123 = collect_sorted([c1.wait, c2.wait, c3.wait])
  a(c123)
end

puts "FINISHED in #{Time.now - start}s."
puts "RESULT = #{result}" # 0bbe9ecf251ef4131dd43e1600742cfb
puts "VALID: #{result == "0bbe9ecf251ef4131dd43e1600742cfb"}"

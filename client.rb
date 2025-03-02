require 'openssl'
require 'faraday'
require 'async'
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

A_SEMAPHORE = Async::Semaphore.new(3)
B_SEMAPHORE = Async::Semaphore.new(2)
C_SEMAPHORE = Async::Semaphore.new(1)

def a(value)
  A_SEMAPHORE.acquire do
    puts "https://localhost:9292/a?value=#{value}"
    Faraday.get("https://localhost:9292/a?value=#{value}").body
  end
end

def b(value)
  B_SEMAPHORE.acquire do
    puts "https://localhost:9292/b?value=#{value}"
    Faraday.get("https://localhost:9292/b?value=#{value}").body
  end
end

def c(value)
  C_SEMAPHORE.acquire do
    puts "https://localhost:9292/c?value=#{value}"
    Faraday.get("https://localhost:9292/c?value=#{value}").body
  end
end

# Референсное решение, приведённое ниже работает правильно, занимает ~19.5 секунд
# Надо сделать в пределах 7 секунд

def collect_sorted(arr)
  arr.sort.join('-')
end

def a_collection(number)
  Sync do |parent|
    [1, 2, 3].map do |n|
      parent.async do
        a("#{number}#{n}")
      end
    end.map(&:wait)
  end
end

def part(number)
  a_collection, b = Sync do |parent|
    a_collection = parent.async { a_collection(number) }
    b = parent.async { b(number) }
    [a_collection, b].map(&:wait)
  end

  ab = "#{collect_sorted(a_collection)}-#{b}"
  puts "AB#{number} = #{ab}"

  c = c(ab)
  puts "C#{number} = #{c}"
  c
end

def run
  c_collection = Sync do |parent|
    [1, 2, 3].map do |n|
      parent.async do
        part(n)
      end
    end.map(&:wait)
  end

  c123 = collect_sorted(c_collection)
  a(c123)
end

require 'openssl'
require 'faraday'
require 'async'
require 'async/semaphore'
require 'async/barrier'

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

def collect_sorted(arr)
  arr.sort.join('-')
end

start = Time.now


A_SEMAPHORE = Async::Semaphore.new(3)
B_SEMAPHORE = Async::Semaphore.new(2)
C_SEMAPHORE = Async::Semaphore.new(1)
barriers = Hash.new { |hh, kk| hh[kk] = Async::Barrier.new }

@a = Hash.new { |h, k| h[k] = [] }
@b = {}
@c = {}

Async do
  {1 => [11, 12, 13], 2 => [21, 22, 23], 3 => [31, 32, 33]}.each do |index, a_indexes|
    a_indexes.each do |a_index| 
      A_SEMAPHORE.async(parent: barriers[:a][index]) { @a[index] << a(a_index) }
    end

    B_SEMAPHORE.async(parent: barriers[:b][index]) { @b[index] = b(index) }
  end

  [1, 2, 3].each do |index|
    C_SEMAPHORE.async do
      barriers[:a][index].wait
      barriers[:b][index].wait

      ab_value = "#{collect_sorted(@a[index])}-#{@b[index]}"

      puts "AB#{index} = #{ab_value}"

      @c[index] = c(ab_value)

      puts "C#{index} = #{@c[index]}"
    end
  end
end

result = a(collect_sorted(@c.values))


puts "FINISHED in #{Time.now - start}s."
puts "RESULT = #{result}" # 0bbe9ecf251ef4131dd43e1600742cfb
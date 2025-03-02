require_relative 'client'

$stdout = File.open('log.txt', 'w')

start = Time.now

result = run

puts "FINISHED in #{Time.now - start}s."
puts "RESULT = #{result}" # 0bbe9ecf251ef4131dd43e1600742cfb

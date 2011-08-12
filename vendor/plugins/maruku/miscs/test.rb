
n=100
$buffer = "blah "*n+"boh"+"beh"*n
$index = n*5

def fun1(reg)
	r2 = /^.{#{$index}}#{reg}/
	r2.match($buffer)
end

def fun2(reg)
	reg.match($buffer[$index, $buffer.size-$index])
end

r = /\w*/
a = Time.now
1000.times do 
	fun1(r)
end

b = Time.now
1000.times do 
	fun2(r)
end

c = Time.now

puts "fun1: #{b-a} sec"
puts "fun2: #{c-b} sec"
require 'socket'
require 'open-uri'

class CLIENT
	hostname = '0.0.0.0'
	port = 8080

	loop do
		puts "=====COMMANDS====="
		puts "WRITE {FILE} MSG {CONTENT}\n"
		puts "READ {FILE}\n"
		puts "=======END======="
		input = STDIN.gets.chomp
		socket = TCPSocket.open(hostname, port)
		socket.print("#{input}\n")
	 if input.include? "READ"
			read_response = socket.gets()	
			puts read_response
		end
		puts "\n"
	end
end

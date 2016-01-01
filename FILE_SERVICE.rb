#!/usr/bin/env ruby

require 'timeout'
require 'socket'
require 'thread'
include Socket::Constants

$DIRECTORY_PORT = 9000

class FILESERVICE
	def readFile (request)
		response = ""
		filename = request.split("READ")[1].strip() 
		socket = TCPSocket.open('0.0.0.0', $DIRECTORY_PORT)
		socket.print("GET #{filename}\n")

		file_exist = File.exist?(File.dirname(__FILE__) + "/files/#{filename}")
		if !file_exist
			puts "File does not exist!"
			response = "File does not exist!"
		else 
	 	File.open(File.dirname(__FILE__) + "/files/#{filename}", "r") do |f|
				f.each_line do |line|
					response << line
				end
			end
			puts "File read succesfully"
		end
		puts "FILE READ: " + response
		response
	end

	def writeFile (request)	
		filename = request.split(" ")[1].strip()
		content = request.split("MSG")[1].strip()
		file_exist = File.exist?(File.dirname(__FILE__) + "/files/#{filename}")
		if !file_exist
			puts "Writing file to #{filename}"
			File.write(File.dirname(__FILE__) + "/files/#{filename}", "#{content}\n")
		else
			File.open(File.dirname(__FILE__) + "/files/#{filename}", "a") { |f|
			f.write("#{content}\n") }
		end
		puts "File written"
		file_written = "File written to #{filename}\n"
		socket = TCPSocket.open('0.0.0.0', $DIRECTORY_PORT)
		socket.print("ADD IP:#$address" + "PORT:#$port" + "FILE:" +	"#{filename}\n")
		puts "Directory service message sent"
	end
end

class THREADPOOL 
	def initialize()
		$work_q = Queue.new
	end
	
	def file_service (client)
	 file_service = FILESERVICE.new
 	 (0..50).to_a.each{|x| $work_q.push x}
	 workers = (0...4).map do
		Thread.new do
			begin
			 while x = $work_q.pop(true)
			  client_request = client.gets()
				 puts "#{client_request}"
					case client_request
						when /READ/
			  		client_res = file_service.readFile(client_request)
						when /WRITE/
							client_res = file_service.writeFile(client_request)
						else
							client_res = "Error"
					end
					client.puts client_res
			 end
			rescue ThreadError
		  end
		end
	 end; "ok"
	workers.map(&:join); "ok"
	end
end

class FILE_SERVICE_MAIN
	threadpool = THREADPOOL.new
	$address = '0.0.0.0'
	$port = ARGV[0]
	tcpServer = TCPServer.new($address, $port)
	puts "File Service server running #$address on #$port"
	loop do
		Thread.fork(tcpServer.accept) do |client|
		 threadpool.file_service client 
		 client.close
		end
	end
end	

#!/usr/bin/env ruby

require 'openssl'
require 'base64'
require 'socket'
require 'thread'
include Socket::Constants

$DIRECTORY_PORT = 9000
$LOCK_PORT = 9001

class FILESERVICE
	def readFile (request)
		response = ""
		filename = request.split("READ")[1].strip() 

		#	Send encrypted file location lookup to directory service
		directory_socket = TCPSocket.open('0.0.0.0', $DIRECTORY_PORT)
		message_directory = "GET #{filename}"
		encrypted_string = Base64.encode64($public_key.public_encrypt(message_directory))
		puts "\nSending ENCRYPTED GET"
		puts "=====BEGIN====="
		puts "#{encrypted_string}"
		puts "======END======\n"
		directory_socket.print("GET #{encrypted_string}\n")
		
		# Send encrypted lock request to lock service
		lock_socket = TCPSocket.open('0.0.0.0', $LOCK_PORT)
		message_lock = "REQUEST #{filename}"
		encrypted_string = Base64.encode64($public_key.public_encrypt(message_lock))
		puts "\nSending LOCK REQUEST"
		puts "=====BEGIN====="
		puts "#{encrypted_string}"
		puts "======END======\n"
		lock_socket.print("REQUEST #{encrypted_string}\n")
		status = lock_socket.gets()

		if status  
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
			# Send encrypted lock release to lock service
			message_lock = "RELEASE #{filename}"
			encrypted_string = Base64.encode64($public_key.public_encrypt(message_lock))
			puts "\nSending ENCRYPTED RELEASE"
			puts "=====BEGIN====="
			puts "#{encrypted_string}"
			puts "======END======\n"
			lock_socket.print("RELEASE #{encrypted_string}")
			puts "FILE READ: " + response
			response
		end
	end

	def writeFile (request)	
		filename = request.split(" ")[1].strip()
		content = request.split("MSG")[1].strip()

		# Send encrypted lock request to lock service
		lock_socket = TCPSocket.open('0.0.0.0', $LOCK_PORT)
		message_lock = "REQUEST #{filename}"
		encrypted_string = Base64.encode64($public_key.public_encrypt(message_lock))
		puts "\nSending ENCRYPTED REQUEST LOCK"
		puts "=====BEGIN====="
		puts "#{encrypted_string}"
		puts "======END======\n"
		lock_socket.print("REQUEST #{encrypted_string}\n")
		status = lock_socket.gets()

		if status
			file_exist = File.exist?(File.dirname(__FILE__) + "/files/#{filename}")
			if !file_exist
				puts "Writing file to #{filename}"
				File.write(File.dirname(__FILE__) + "/files/#{filename}", "#{content}\n")
			else
				File.open(File.dirname(__FILE__) + "/files/#{filename}", "a") { |f|
				f.write("#{content}\n") }
			end
			# Send encrypted lock release to lock service
			message_lock = "RELEASE #{filename}"
			encrypted_string = Base64.encode64($public_key.public_encrypt(message_lock))
			puts "\nSending LOCK RELEASE"
			puts "=====BEGIN====="
			puts "#{encrypted_string}"
			puts "======END======\n"
			lock_socket.print("RELEASE #{encrypted_string}\n");
		end
		puts "File written"
		file_written = "File written to #{filename}\n"

		# Send encrypted write location to directory service
		directory_socket = TCPSocket.open('0.0.0.0', $DIRECTORY_PORT)
		message_directory = "ADD IP:#$address" + "PORT:#$port" + "FILE:" + "#{filename}\n"
		encrypted_string = Base64.encode64($public_key.public_encrypt(message_directory))
		puts "\nSending ENCRYPTED ADD"
		puts "=====BEGIN====="
		puts "#{encrypted_string}"
		puts "======END======\n"
		directory_socket.print("ADD #{encrypted_string}")
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
	public_key_file = 'public.pem'
	$public_key = OpenSSL::PKey::RSA.new(File.read(public_key_file))
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

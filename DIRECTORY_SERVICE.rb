#!/usr/bin/env ruby

require 'socket'
require 'thread'
include Socket::Constants

class DATABASE
	def initialize()
		$file = { }
		$address = { }
		$port = { }
		@lock = Mutex.new
	end

	def setFileLocation ( file_id, file, address, port )
		@lock.synchronize {
			$file[file_id] = file	
			$address[file_id] = address
			$port[file_id] = port
		}
	end
	
	def getFileLocation ( file_id )
		@lock.synchronize {
			file = $file[file_id]
		}
	end

	def getAddress ( file_id )
		@lock.synchronize {
			address = $address[file_id]
		}
	end

	def getPort ( file_id )
		@lock.synchronize {
			port = $port[file_id]
		}
	end
end

class DIRECTORYSERVICE
	def add (request)
		parse = request.split("ADD")[1].strip()

		file = parse.split("FILE:")[1].strip()

	 portIP = parse.split("FILE:")[0].strip()
		port = portIP.split("PORT:")[1].strip()

		ip = portIP.split("PORT:")[0].strip()
		server_ip = ip.split("IP:")[1].strip()

		$database.setFileLocation( file.to_i, file, server_ip, port )
	end
	
	def get (request)
		parse = request.split("GET")[1].strip()
		file = $database.getFileLocation( parse.to_i ) 
		address = $database.getAddress( parse.to_i )
		port = $database.getPort( parse.to_i )
		puts "#{file}, #{address}, #{port}"
	end
end

class THREADPOOL 
	def initialize()
		$work_q = Queue.new
	end
	
	def directory_service (client)
	 directory_service = DIRECTORYSERVICE.new
 	 (0..50).to_a.each{|x| $work_q.push x}
	 workers = (0...4).map do
		Thread.new do
			begin
			 while x = $work_q.pop(true)
					client_request = client.gets()
					puts "Request: #{client_request}"
					case client_request
						when /ADD/
							directory_service.add(client_request)	
						when /GET/
							directory_service.get(client_request)
					end
				end
			rescue ThreadError
		  end
		end
	 end; "ok"
	workers.map(&:join); "ok"
	end
end

class DIRECTORY_SERVICE_MAIN
	threadpool = THREADPOOL.new
	$database = DATABASE.new
	address = '0.0.0.0'
	port = 9000
	tcpServer = TCPServer.new(address, port)
	puts "Directory Service server running #{address} on #{port}"
	loop do
		Thread.fork(tcpServer.accept) do |client|
		 threadpool.directory_service client 
		 client.close
		end
	end
end	

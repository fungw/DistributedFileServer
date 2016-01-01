#!/usr/bin/env ruby

require 'socket'
require 'thread'
include Socket::Constants

class DATABASE
	def initialize()
		$file = { }
		@lock = Mutex.new
	end

	def setLock ( file_id )
		@lock.synchronize {
			$file[file_id] = true
		}
	end

 def releaseLock ( file_id )
		@lock.synchronize {
			$file[file_id] = false
		}
	end

	def lockedRequest ( file_id )
		@lock.synchronize {
			status = $file[file_id]
		}
	end
end

class LOCKINGSERVICE
	def request ( request )
		file = request.split("REQUEST")[1].strip()
		status = $database.lockedRequest(file.to_i)	
		if !status
			setLock(file.to_i)	
		end
		status
	end

	def release ( request )
		file = request.splti("RELEASE")[1].strip()
		$database.releaseLock(file.to_i) 
	end
end

class THREADPOOL 
	def initialize()
		$work_q = Queue.new
	end
	
	def locking_service (client)
	 lock_service = LOCKINGSERVICE.new
 	 (0..50).to_a.each{|x| $work_q.push x}
	 workers = (0...4).map do
		Thread.new do
			begin
			 while x = $work_q.pop(true)
			  client_request = client.gets()
				 puts "#{client_request}"
					case client_request
						when /REQUEST/
							status = lock_service.request(client_request)
						when /RELEASE/
							lock_service.release(client_request)
							status = "RELEASED"
			 	end
					client.puts status
			end
			rescue ThreadError
		  end
		end
	 end; "ok"
	workers.map(&:join); "ok"
	end
end

class LOCKING_SERVICE_MAIN
	threadpool = THREADPOOL.new
	$database = DATABASE.new 
	$address = '0.0.0.0'
	$port = 9001
	tcpServer = TCPServer.new($address, $port)
	puts "File Service server running #$address on #$port"
	loop do
		Thread.fork(tcpServer.accept) do |client|
		 threadpool.locking_service client 
		 client.close
		end
	end
end	

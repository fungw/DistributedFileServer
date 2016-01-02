#!/usr/bin/env ruby

require 'openssl'
require 'base64'
require 'socket'
require 'thread'
include Socket::Constants

$LOCK_PORT = 9100

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
	def request ( encrypted_request )
		# Decrypt message
		remove_request = encrypted_request.split("REQUEST")[1].strip()
		request = $private_key.private_decrypt(Base64.decode64(remove_request))
		puts "DECRYPTED REQUEST MESSAGE"
		puts "=====BEGIN====="
		puts "#{request}"
		puts "======END======"
		
		file = request.split("REQUEST")[1].strip()
		status = $database.lockedRequest(file.to_i)	
		if status.nil?
			$database.setLock(file.to_i)	
			status = $database.lockedRequest(file.to_i)
		end
		status
	end

	def release ( encrypted_request )
		# Decrypt message 
		remove_request = encrypted_request.split("RELEASE")[1].strip()
		request = $private_key.private_decrypt(Base64.decode64(remove_request))
		puts "DECRYPTED RELEASE MESSAGE"
		puts "=====BEGIN====="
		puts "#{request}"
		puts "======END======"

		file = request.split("RELEASE")[1].strip()
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
					client_request = ""
					while !client_request.include? "==" do
			  	message = client.gets()
						client_request << message
					end
					puts "\nMessage received:"
					puts "=====BEGIN====="
					puts "#{client_request}"
					puts "======END======\n"
					case client_request
						when /REQUEST/
							status = lock_service.request(client_request)
							puts "LOL :: #{status}"
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

	private_key_file = 'private.pem'
	password = 'fortyone'
	$private_key = OpenSSL::PKey::RSA.new(File.read(private_key_file), password)

	$database = DATABASE.new 
	$address = '0.0.0.0'
	tcpServer = TCPServer.new($address, $LOCK_PORT)
	puts "Locking Service server running #$address on #$port"
	loop do
		Thread.fork(tcpServer.accept) do |client|
		 threadpool.locking_service client 
		 client.close
		end
	end
end	

#!/usr/bin/env ruby

require 'openssl'
require 'base64'
require 'socket'
require 'thread'
include Socket::Constants

$AS_PORT = 9200
$JOIN_ID_COUNTER = 0;

class DATABASE
	def initialize()
		$username = { }
		$password = { }
		$login = { } 
		@lock = Mutex.new
	end

	def registerUser ( join_id, username, password )
		@lock.synchronize {
			$username[join_id] = username
			$password[join_id] = password
			puts "Registering user #{username}, #{join_id}"
			$login[join_id] = false
		}
	end

	def login ( join_id, username, password )
		@lock.synchronize {
			check_username = $username[join_id]
			check_password = $password[join_id]
			if ((check_username.eql?(username)) && (check_password.eql?(password)))
				puts "Login user #{username}, #{join_id}"
				$login[join_id] = true
			end
			status = $login[join_id]
		}
	end

	def logout ( join_id, username )
		@lock.synchronize {
			check_username = $username[join_id]
			if (check_username == username)
				puts "Logout user #{username}, #{join_id}"
				$login[join_id] = false
			end
		}
	end
end

class AS_SERVICE
	def register ( encrypted_request )
		# Decrypt message
		remove_request = encrypted_request.split("REGISTER")[1].strip()
		request = $private_key.private_decrypt(Base64.decode64(remove_request))
		puts "DECRYPTED REGISTER MESSAGE"
		puts "=====BEGIN====="
		puts "#{request}"
		puts "======END======"
		
		register = request.split("REGISTER")[1].strip()
		password = register.split("PASSWORD:")[1].strip()
		remove_PW = register.split("PASSWORD")[0].strip()
		username = remove_PW.split("USERNAME:")[1].strip()
		join_id = username.hash
		$database.registerUser( join_id, username, password )
		status = $database.login( join_id, username, password )
		$database.logout( join_id, username )
		status
	end

	def login ( encrypted_request )
		# Decrypt message 
		remove_request = encrypted_request.split("LOGIN")[1].strip()
		request = $private_key.private_decrypt(Base64.decode64(remove_request))
		puts "DECRYPTED LOGIN MESSAGE"
		puts "=====BEGIN====="
		puts "#{request}"
		puts "======END======"

		login = request.split("LOGIN")[1].strip()
		password = login.split("PASSWORD:")[1].strip()
		remove_PW = login.split("PASSWORD:")[0].strip()
		username = remove_PW.split("USERNAME:")[1].strip()
		join_id = username.hash
		status = $database.login( join_id, username, password)
	end

	def logout ( encrypted_request )
		# Decrypt message
		remove_request = encrypted_request.split("LOGOUT")[1].strip()
		request = $private_key.private_decrypt(Base64.decode64(remove_request))
		puts "DECRYPTED LOGOUT MESSAGE"
		puts "=====BEGIN====="
		puts "#{request}"
		puts "======END======"

		logout = request.split("LOGOUT")[1].strip()
	end
end

class THREADPOOL 
	def initialize()
		$work_q = Queue.new
	end
	
	def as_service (client)
	 as_service = AS_SERVICE.new
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
						when /REGISTER/
							status = as_service.register(client_request)
						when /LOGIN/
							status = as_service.login(client_request)
						when /LOGOUT/
							status = as_service.logout(client_request)
			 	end
					puts "Sending: #{status}"
					client.puts status
			end
			rescue ThreadError
		  end
		end
	 end; "ok"
	workers.map(&:join); "ok"
	end
end

class AS_SERVICE_MAIN
	threadpool = THREADPOOL.new

	public_key_file = 'public.pem'
	$public_key = OpenSSL::PKey::RSA.new(File.read(public_key_file))

	private_key_file = 'private.pem'
	password = 'fortyone'
	$private_key = OpenSSL::PKey::RSA.new(File.read(private_key_file), password)

	$database = DATABASE.new 
	$address = '0.0.0.0'
	tcpServer = TCPServer.new($address, $AS_PORT)
	puts "Authentication Server Service server running #$address on #$AS_PORT"
	loop do
		Thread.fork(tcpServer.accept) do |client|
		 threadpool.as_service client 
		 client.close
		end
	end
end	

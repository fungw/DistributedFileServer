#!/usr/bin/env ruby

require 'rubygems'
require 'socket'
require 'digest'
require 'io/console'
require 'uri'
require 'open-uri'
require 'openssl'
require 'base64'

class CLIENT
	hostname = '0.0.0.0'
	port = ARGV[0]

	public_key_file = 'public.pem'
	$public_key = OpenSSL::PKey::RSA.new(File.read(public_key_file))
	$current_user_id = ""

	$AS_PORT = 9200
	login_status = false
	Auth_socket = TCPSocket.open(hostname, $AS_PORT)
	while login_status == false do
		puts "(1) Register"	
		puts "(2) Login\n"
		input = STDIN.gets.chomp
		case input 
			when /1/
				puts "Username:"
				username = STDIN.gets.chomp
				puts "Password:"
				encrypted_pw = STDIN.noecho(&:gets).chomp
				message_AS = "REGISTER USERNAME:#{username}PASSWORD:#{encrypted_pw}"
				encrypted_string = Base64.encode64($public_key.public_encrypt(message_AS))
				Auth_socket.print("REGISTER #{encrypted_string}")
				reg_status = Auth_socket.gets()
				case reg_status
					when /true/
						puts "Registration successful!\n"
					when /false/
						puts "Registration failed, try again\n"
				end
			when /2/
				puts "Username:"
				username = STDIN.gets.chomp
				puts "Password:"
				encrypted_pw = STDIN.noecho(&:gets).chomp

			 # Encrypted password length must be of a certain length
			# so that we will be able to encrypt it; reflects the block size
			while encrypted_pw.length < 24 do
				encrypted_pw << '0'
			end
			message_AS = "encrypt this"
			des = OpenSSL::Cipher::Cipher.new("des-ede3-cbc")
			des.encrypt
			# Initialisation Vector has a fixed length of 9 characters; randomised
			vector = ""
			for i in 0..7 do
				vector << Random.rand(0..9).to_s	
			end
			puts vector.length
			des.iv = iv = vector
			data = des.update(message_AS) + des.final
			data = iv + data

			data = Base64.encode64(data)
		 	data = URI.escape(data, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))

			des = OpenSSL::Cipher::Cipher.new("des-ede3-cbc")
			des.decrypt
			des.key = encrypted_pw
			encrypted_data = URI.unescape(data)
			encrypted_data = Base64.decode64(data)
			des.iv =  encrypted_data.slice!(0,8) #This gives us our iv back and removes it from the encrypted data
													  
			decrypted = des.update(encrypted_data) + des.final  
			puts "HEY"
			puts decrypted

			puts "Before encode: #{data}"

			# Encode our data before sending
			encrypted_string = Base64.encode64($public_key.public_encrypt(data))
			sending = "LOGIN USERNAME:#{username}DATA:#{encrypted_string}"

			puts "Encrypted string before sending: #{encrypted_string}"
			Auth_socket.print("#{sending}")
			status = Auth_socket.gets()
			puts "Login status: #{status}"
			case status
				when /true/
					puts "Login successful!\n"
					login_status = true
				when /false/
					puts "Login failed, try again\n"
			end
		end
	end

	loop do
		puts "\n=====COMMANDS====="
		puts "WRITE {FILE} MSG {CONTENT}\n"
		puts "READ {FILE}\n"
		puts "LOGOUT\n"
		puts "=======END======="
		input = STDIN.gets.chomp
		socket = TCPSocket.open(hostname, port)
		socket.print("#{input}\n")
	 if input.include? "READ"
			read_response = socket.gets()	
			puts read_response
		end
		if input.include? "LOGOUT"
			logout_socket = TCPSocket.open(hostname, $AS_PORT)
			logout_socket.print("LOGOUT")
			exit(true)
		end
		puts "\n"
	end
end

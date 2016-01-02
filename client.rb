require 'socket'
require 'digest'
require 'io/console'
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
				password = STDIN.noecho(&:gets).chomp
				encrypted_pw = Digest::SHA256.digest password	
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
				password = STDIN.noecho(&:gets).chomp
				encrypted_pw = Digest::SHA256.digest password
				message_AS = "LOGIN USERNAME:#{username}PASSWORD:#{encrypted_pw}"
				encrypted_string = Base64.encode64($public_key.public_encrypt(message_AS))
				Auth_socket.print("LOGIN #{encrypted_string}")
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

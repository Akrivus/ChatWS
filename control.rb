require "csv"
require "date"
require "digest"
require "erb"
require "glorify"
require "oj"
require "rack"
require "sinatra"
require "sinatra-websocket"
require "thread"
require "uri"

require_relative "command.rb"

# Pretty sure this is 'websocket' as SHA256.
set :session_secret, "7ce54cbababdd64826b853179905315617306f430e5154177ddbed04c282b7da"
set :session_provider, "sinatra" # "rack"
set :server, "thin"
set :bind, "0.0.0.0"

# This behemoth provides the user session.
if settings.session_provider == "rack"
    use Rack::Session::Cookie,
        secret: settings.session_secret
else
    enable :sessions
end

# Sockets are stored as a hash so I can lookup through name.
set :sockets, {}
set :logs, []

# Login section.
get  "/" do
    if not session["name"].nil?
        redirect "/chat"
    else
        erb :index, locals: { error: nil }
    end
end
post "/" do
    if params.include? "name"
        response = erb :index, locals: { error: "Incorrect password." }
        with_users do |users|
            all_clear = true
            if not users[params["name"]].nil?
                if users[params["name"]].include? "password"
                    if digest(params["password"]) != users[params["name"]]["password"]
                        all_clear = false
                    end
                end
            else
                if not params["password"].empty?
                    users[params["name"]] = { "password" => digest(params["password"]) }
                end
            end
            if all_clear
                session["name"] = unxss(params["name"]) # Prevent XSS.
                response = redirect "/chat"
                if not session["name"].nil?
                    users[session["name"]]["password"] = digest(params["password"])
                end
            end
        end
        response
    else
        redirect "/"
    end
end

# Chat section.
get  "/chat" do
    if session["name"].nil? # User isn't logged in.
        redirect "/"
    else
        if request.websocket?
            request.websocket do |socket|
                socket.onopen do
                    # Send them the GPL notice and any helpful commands. 
                    socket.send(erb(:message_of_the_day))
                    # Add them to the userlist and notify everyone.
                    settings.sockets[session["name"]] = socket
                    settings.sockets.each do |user, sockets|
                        sockets.send(erb(:message_user_join, locals: { name: session["name"] }))
                    end
                    with_users do |users|
                        if not users[session["name"]].nil?
                            if not users[session["name"]]["notes"].nil?
                                not users[session["name"]]["notes"] = []
                            end
                        end
                    end
                end
                socket.onclose do
                    # Delete the socket connection so we don't crash.
                    settings.sockets.tap do |key|
                        key.delete(session["name"])
                    end
                    # Notify everyone that the user left.
                    settings.sockets.each do |user, socket|
                        socket.send(erb(:message_user_left, locals: { name: session["name"] }))
                    end
                end
                socket.onmessage do |message|
                    message = unxss(message)
                    if can_send? message, settings.sockets, session["name"]
                        settings.sockets.each do |user, socket|
                            socket.send(erb(:message_user_public, locals: { name: session["name"], message: message, stamp: timestamp }))
                            settings.logs.push({ name: session["name"], message: message, stamp: timestamp })
                            if settings.logs.length > 10
                                settings.logs.shift
                            end
                        end
                        with_users do |users|
                            if users[session["name"]].nil?
                                users[session["name"]] = { "lastSeen" => timestamp }
                            else
                                users[session["name"]]["lastSeen"] = timestamp
                            end
                        end
                    end
                end
            end
        else
            erb :chatroom
        end
    end
end
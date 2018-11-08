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
        name = unxss(params["name"]).gsub(" ", "_")
        password = digest(params["password"])
        all_clear = true
        with_user(name) do |user|
            if user.key? "password"
                if user["password"] != password
                    all_clear = false
                end
            end
        end
        if all_clear
            if not params["password"].empty?
                session["password"] = password
            end
            session["name"] = name
            response = redirect "/chat"
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
                    with_user(session["name"]) do |user|
                        user["password"] = session["password"]
                        user["lastSeen"] = timestamp
                        if user.key? "notes"
                            user["notes"].each do |hash|
                                hash.each do |name, note|
                                    settings.sockets[session["name"]].send(erb(:message_yell_command, locals: { name: name, text: note }))
                                end
                            end
                        end
                        user["notes"] = []
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
                    end
                    with_user(session["name"]) do |user|
                        user["lastSeen"] = timestamp
                    end
                end
            end
        else
            erb :chatroom
        end
    end
end
require "sinatra"
require "sinatra-websocket"

enable :sessions
set :server, "webrick"
set :bind, "0.0.0.0"
set :sockets, []

# Login shits.
get  "/" do
    erb :index
end
post "/join" do
    if params.include? "name"
        session["name"] = params["name"]
        redirect "/chat"
    else
        redirect "/"
    end
end

# Websocket shits.
get  "/chat" do
    if session["name"].nil?
        redirect "/"
    elsif request.websocket?
        request.websocket do |socket|
            socket.onopen do
                settings.sockets.push(socket)
                settings.sockets.each do |socket|
                    socket.send(erb(:join_message, locals: { name: session["name"] }))
                end
            end
            socket.onmessage do |message|
                settings.sockets.each do |socket|
                    socket.send(erb(:chat_message, locals: { name: session["name"], message: message}))
                end
            end
            ws.onclose do
                settings.sockets.delete(socket)
                settings.sockets.each do |socket|
                    socket.send(erb(:left_message, locals: { name: session["name"] }))
                end
            end
        end
    else
        redirect "/"
    end
end
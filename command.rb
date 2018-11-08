def can_send?(message, users, name)
    args = message.split(" ")
    if args[0].start_with? "!"
        case args[0]
        when "!help"
            show_help(users, name)
        when "!show"
            show_license(users, name)
        when "!pass"
            change_password(args[1..-1], users, name)
        when "!seen"
            seen(args[1], users, name)
        when "!tell"
            tell(args[1], args[2..-1].join(" "), users, name)
        when "!yell"
            yell(args[1..-1].join(" "), users, name)
        when "!pick"
            pick(users, name)
        when "!dice"
            dice(users, name)
        when "!flip"
            flip(users, name)
        when "!ball"
            ball(users, name)
        when "!motd"
            motd(args[1..-1].join(" "), users, name)
        end
        false
    else
        true
    end
end
def show_help(users, name)
    users[name].send(erb(:message_help_command))
end
def show_license(users, name)
    users[name].send(erb(:message_show_command))
end
def change_password(arg, users, name)
    users[name].send(erb(:message_command, locals: { text: "Your password has been changed successfully." }))
    with_user(name) do |user|
        user["password"] = digest(arg)
    end
end
def seen(arg, users, name)
    with_user(arg) do |user|
        if user["lastSeen"].nil?
            users[name].send(erb(:message_command, locals: { text: "#{arg} has never been on this chat before." }))
        else
            users[name].send(erb(:message_seen_command, locals: { name: arg, time: user["lastSeen"] }))
        end
    end
end
def tell(arg, message, users, name)
    with_user(arg) do |user|
        if user["notes"].nil?
            users[name].send(erb(:message_command, locals: { text: "#{arg} has never been on this chat before." }))
        else
            users[name].send(erb(:message_command, locals: { text: "Your message has been sent to #{name}!" }))
            user["notes"].push({ name => message })
        end
    end
end
def yell(message, users, name)
    users.each do |user, sockets|
        sockets.send(erb(:message_yell_command, locals: { name: name, text: message }))
    end
end
def pick(users, name)
    name_picked = users.keys.sample
    users.each do |user, sockets|
        sockets.send(erb(:message_pick_command, locals: { name: name, pick: name_picked }))
    end
end
def dice(users, name)
    users.each do |user, sockets|
        sockets.send(erb(:message_dice_command, locals: { name: name, roll: rand(1..6) }))
    end
end
def flip(users, name)
    users.each do |user, sockets|
        sockets.send(erb(:message_flip_command, locals: { name: name, flip: rand(0..1) }))
    end
end
def ball(users, name)
    users.each do |user, sockets|
        sockets.send(erb(:message_ball_command, locals: { name: name }))
    end
end
def motd(arg, users, name)
    if File.exist? "./private/motd.json"
        message = Oj.load_file("./private/motd.json")
    end
    message["motd"] = arg
    Oj.to_file("./private/motd.json", message)
    users.each do |user, sockets|
        sockets.send(erb(:message_command, locals: { text: "MOTD has been changed to &ldquo;#{arg}&rdquo;" }))
    end
end

# Escapes HTML tags, prevents XSS attacks.
def unxss(message)
    message.gsub(/<\/*\w+>/, "")
end
def digest(input)
    return Digest::SHA256.hexdigest(input)
end
def with_user(name)
    users = {}
    if File.exist? "./private/users.json"
        users = Oj.load_file("./private/users.json")
    end
    if not users.key? name
        users[name] = {}
    end
    yield(users[name])
    Oj.to_file("./private/users.json", users)
end
def timestamp
    Time.now.to_i
end
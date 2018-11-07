def can_send?(message, users, user)
    if message.start_with? "!"
        
    end
    true
end


# Escapes HTML tags, prevents XSS attacks.
def unxss(message)
    message.gsub(/<\/*\w+>/, "")
end
def digest(input)
    return Digest::SHA256.hexdigest(input)
end
def with_users
    users = {}
    if File.exist? "./private/users.json"
        users = Oj.load_file("./private/users.json")
    end
    yield(users)
    Oj.to_file("./private/users.json", users)
end
def timestamp
    Time.now.to_i
end
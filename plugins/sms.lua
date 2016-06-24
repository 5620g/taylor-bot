local function run(msg, matches)

  if not is_sudo(msg) then 

    return 'فقط برای سودو ها'

  end

  if matches[1]:lower() == 'sms' and is_sudo(msg) then

    local response = matches[3]

    send_large_msg("user#id"..matches[2], response)

            local receiver = 'user#id'..user_id

        send_large_msg(receiver, response)

  end

  end

return {

  patterns = {

    "^[!/](sms) (%d+) (.*)$"

  },

  run = run

}

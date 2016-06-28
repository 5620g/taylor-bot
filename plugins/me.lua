do function run(msg, matches)

	  if matches[1]:lower() == 'wai' and is_sudo(msg) then
      return "You are SUDO"
      end
      if matches[1]:lower() == 'wai' and is_admin(msg) then
      return "You are Admin"
      end
      if matches[1]:lower() == 'wai' and is_owner(msg) then
      return "You are Group Leader"
      end
      if matches[1]:lower() == 'wai' and is_momod(msg) then
      return "You are Group Moderator"
      end
      if matches[1]:lower() == 'wai' then
      return "You are Group Member"
    end
      if matches[1]:lower() == 'مقام' and is_sudo(msg) then
      return "شما سازنده ربات هستيد"
      end
      if matches[1]:lower() == 'مقام' and is_admin(msg) then
      return "شما ادمين ربات هستيد"
      end
      if matches[1]:lower() == 'مقام' and is_owner(msg) then
      return "شما مدير اصلي گروه هستيد"
      end
      if matches[1]:lower() == 'مقام' and is_momod(msg) then
      return "شما کمک مدير هستيد"
      end
      if matches[1]:lower() == 'مقام' then
      return "شما عضو ساده هستيد"
    end
end
  return {
  description = "Your Postation In Group",
  usage = "Wai",
  patterns = {
  "^([Ww][Aa][Ii])$",
  "^(مقام)$"
    },
  run = run
}
end

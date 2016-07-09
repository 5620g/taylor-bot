package.path = package.path .. ';.luarocks/share/lua/5.2/?.lua'
  ..';.luarocks/share/lua/5.2/?/init.lua'
package.cpath = package.cpath .. ';.luarocks/lib/lua/5.2/?.so'

require("./bot/utils")

local f = assert(io.popen('/usr/bin/git describe --tags', 'r'))
VERSION = assert(f:read('*a'))
f:close()

-- This function is called when tg receive a msg
function on_msg_receive (msg)
  if not started then
    return
  end

  msg = backward_msg_format(msg)

  local receiver = get_receiver(msg)
  print(receiver)
  --vardump(msg)
  --vardump(msg)
  msg = pre_process_service_msg(msg)
  if msg_valid(msg) then
    msg = pre_process_msg(msg)
    if msg then
      match_plugins(msg)
      if redis:get("bot:markread") then
        if redis:get("bot:markread") == "on" then
          mark_read(receiver, ok_cb, false)
        end
      end
    end
  end
end

function ok_cb(extra, success, result)

end

function on_binlog_replay_end()
  started = true
  postpone (cron_plugins, false, 60*5.0)
  -- See plugins/isup.lua as an example for cron

  _config = load_config()

  -- load plugins
  plugins = {}
  load_plugins()
end

function msg_valid(msg)
  -- Don't process outgoing messages
  if msg.out then
    print('\27[36mNot valid: msg from us\27[39m')
    return false
  end

  -- Before bot was started
  if msg.date < os.time() - 5 then
    print('\27[36mNot valid: old msg\27[39m')
    return false
  end

  if msg.unread == 0 then
    print('\27[36mNot valid: readed\27[39m')
    return false
  end

  if not msg.to.id then
    print('\27[36mNot valid: To id not provided\27[39m')
    return false
  end

  if not msg.from.id then
    print('\27[36mNot valid: From id not provided\27[39m')
    return false
  end

  if msg.from.id == our_id then
    print('\27[36mNot valid: Msg from our id\27[39m')
    return false
  end

  if msg.to.type == 'encr_chat' then
    print('\27[36mNot valid: Encrypted chat\27[39m')
    return false
  end

  if msg.from.id == 777000 then
    --send_large_msg(*group id*, msg.text) *login code will be sent to GroupID*
    return false
  end

  return true
end

--
function pre_process_service_msg(msg)
   if msg.service then
      local action = msg.action or {type=""}
      -- Double ! to discriminate of normal actions
      msg.text = "!!tgservice " .. action.type

      -- wipe the data to allow the bot to read service messages
      if msg.out then
         msg.out = false
      end
      if msg.from.id == our_id then
         msg.from.id = 0
      end
   end
   return msg
end

-- Apply plugin.pre_process function
function pre_process_msg(msg)
  for name,plugin in pairs(plugins) do
    if plugin.pre_process and msg then
      print('Preprocess', name)
      msg = plugin.pre_process(msg)
    end
  end
  return msg
end

-- Go over enabled plugins patterns.
function match_plugins(msg)
  for name, plugin in pairs(plugins) do
    match_plugin(plugin, name, msg)
  end
end

-- Check if plugin is on _config.disabled_plugin_on_chat table
local function is_plugin_disabled_on_chat(plugin_name, receiver)
  local disabled_chats = _config.disabled_plugin_on_chat
  -- Table exists and chat has disabled plugins
  if disabled_chats and disabled_chats[receiver] then
    -- Checks if plugin is disabled on this chat
    for disabled_plugin,disabled in pairs(disabled_chats[receiver]) do
      if disabled_plugin == plugin_name and disabled then
        local warning = 'Plugin '..disabled_plugin..' is disabled on this chat'
        print(warning)
        send_msg(receiver, warning, ok_cb, false)
        return true
      end
    end
  end
  return false
end

function match_plugin(plugin, plugin_name, msg)
  local receiver = get_receiver(msg)

  -- Go over patterns. If one matches it's enough.
  for k, pattern in pairs(plugin.patterns) do
    local matches = match_pattern(pattern, msg.text)
    if matches then
      print("msg matches: ", pattern)

      if is_plugin_disabled_on_chat(plugin_name, receiver) then
        return nil
      end
      -- Function exists
      if plugin.run then
        -- If plugin is for privileged users only
        if not warns_user_not_allowed(plugin, msg) then
          local result = plugin.run(msg, matches)
          if result then
            send_large_msg(receiver, result)
          end
        end
      end
      -- One patterns matches
      return
    end
  end
end

-- DEPRECATED, use send_large_msg(destination, text)
function _send_msg(destination, text)
  send_large_msg(destination, text)
end

-- Save the content of _config to config.lua
function save_config( )
  serialize_to_file(_config, './data/config.lua')
  print ('saved config into ./data/config.lua')
end

-- Returns the config from config.lua file.
-- If file doesn't exist, create it.
function load_config( )
  local f = io.open('./data/config.lua', "r")
  -- If config.lua doesn't exist
  if not f then
    print ("Created new config file: data/config.lua")
    create_config()
  else
    f:close()
  end
  local config = loadfile ("./data/config.lua")()
  for v,user in pairs(config.sudo_users) do
    print("Sudo user: " .. user)
  end
  return config
end

-- Create a basic config.json file and saves it.
function create_config( )
  -- A simple config with basic plugins and ourselves as privileged user
  config = {
    enabled_plugins = {
	"admin",
    "onservice",
    "inrealm",
    "ingroup",
    "inpm",
    "banhammer",
    "stats",
    "anti_spam",
    "owners",
    "arabic_lock",
    "set",
    "pl",
    "get",
    "broadcast",
    "invite",
    "all",
    "leave_ban",
	"supergroup",
	"whitelist",
	"msg_checks"
    },
    sudo_users = {189308877},--Sudo users
    moderation = {data = 'data/moderation.json'},
    about_text = [[monster v4
    monster TM and monster Bot Anti spam / anti link
    
    website : 
    monster.ir  ❤️
    
    admin : 
    
    @tahajk ❤️
    
    
    channel : 
    
    
    @team_monster ❤️
]],
    help_text_realm = [[
دستورات ریلم:

💢!creategroup [Name]
ساخت گروه

🎈!createrealm [Name]
ساخت ریلم

💢!setname [Name]
تنظیم نام

🎈!setabout [group|sgroup] [GroupID] [Text]
تنظیم درباره یک گروه

💢!setrules [GroupID] [Text]
تنظبم قوانین یک گروه

🎈!lock [GroupID] [setting]
فقط تنظیمات یک گروه

💢!unlock [GroupID] [setting]
باز کردن تنظبمات یک گروه

🎈!settings [group|sgroup] [GroupID]
تنظیم برخی تنظیمات برای یک گروه

💢!wholist
دریافت لیست ممبر های گروه

🎈!who
دریافت فایل ممبر های گروه

💢!type
نمایش حالت گروه

🎈!kill chat [GroupID]
دلیت همه اعضای گروه

💢!kill realm [RealmID]
دلیت همه اعضای ریلم

🎈!addadmin [id|username]
اضافه کردن ادمین*فقط سودو

💢!removeadmin [id|username]
حذف کردن ادمین *فقط سودو

🎈!list groups
لیست همه گروه ها

💢!list realms
لیست همه ریلم ها

🎈!support
دیافت لینک ساپورت

💢!-support
حذف فرد از ساپورت

🎈!log
دریافت اطلاعات اکانت ربات

💢!broadcast [text]
💢!broadcast Hello !
سند تو آل
فقط سودو 

🎈!bc [group_id] [text]
🎈!bc 123456789 Hello !
فرستادن یک متن به گروه خاص 


**شما میتوانید از"#", "!", or "/" برای دستورات استفاده کنین!


*فقط ادمین و سودو میتونه ربات رو اد بده توی گروه ها!


*فقط ادمین میتونه استفاده کنه از دستورات kick,ban,unban,newlink,setphoto,setname,lock,unlock,set rules,set about and settings 

*فقط ادمین و سودو میتونه از دستورات res, setowner, استفاده کنه!
]],
    help_text = [[
لیست دستورات:

💢!kick [username|id]
اخراج فرد از گروه

🎈!ban [ username|id]
بلاک کردن فرد از گروه

💢!unban [id]
آنبلاک کردن فرد از گروه
🎈!who
لیست اعضا

💢!modlist
لیست مدیران

🎈!promote [username]
انتخاب مدیر جدید

💢!demote [username]
حذف مدیر انتخابی

🎈!kickme
اخراج شما

💢!about
نمایش درباره گروه

🎈!setphoto
تنظیم عکس گروه و قفل آن

💢!setname [name]
تنظیم نام گروه و قفل آن

🎈!rules
نمایش قوانین

💢!id
نمایش آیدی

🎈!help
نمایش لیست راهنما

💢!lock [links|flood|spam|Arabic|member|rtl|sticker|contacts|strict]
قفل برخی تنظیمات گروه

🎈!unlock [links|flood|spam|Arabic|member|rtl|sticker|contacts|strict]
باز کردن برخی تنظیمات گروه

💢!mute [all|audio|gifs|photo|video]
بی صدا کردن برخی فایل های ارسالی

🎈!unmute [all|audio|gifs|photo|video]
با صدا کردن برخی فایل های ارسالی

💢!set rules <text>
تنظیم قوانین 

🎈!set about <text>
تنظیم درباره

💢!settings
نمایش تنظیمات گروه

🎈!muteslist
نمایش لیست رسانه های بی صدا و باصدا

💢!muteuser [username]
بی صدا کردن یک یوزر

🎈!mutelist
نمایش لیست بی صدا شده ها

💢!newlink
ساخت لینک جدید(ربات باید سازنده باشد)

🎈!link
نمایش لینک گروه

💢!owner
نمایش ایدی صاحب گروه

🎈!setowner [id]
تنظیم صاحب برای گروه

💢!setflood [value]
تنظیم حساسیت به اسپم

🎈!stats
نمایش اطلاعات گروه

💢!save [value] <text>
ذخیره یک متن در حافظه

🎈!get [value]
نمایش متن ذخیره شده

💢!clean [modlist|rules|about]
پاک کردن مدیران/قوانین/درباره

🎈!res [username]
دریافت اطلاعات یوزرنیم

💢!log
نمایش اطلاعات گروه

🎈!banlist
نمایش لیست بن شده ها

**شما میتوانید از شکلک های"#", "!", or "/" اول همه دستورات استفاده کنین!


*فقط ادمین و سودو میتونن ربات رو توی گروه اد کنن!


*فقط ادمین میتونه استفاده کنه از دستورات kick,ban,unban,newlink,setphoto,setname,lock,unlock,set rules,set about و settings 

*فقط ادمین و سودو میتونه از دستورات res, setowner, استفاده کنه!

]],
	help_text_super =[[
SuperGroup Commands:

💢!info
دریافت اطلاعات گروه و شما

🎈!admins
نمایش ادمین های سوپر گروه

💢!owner
نمایش صاحب گروه

🎈!modlist
نمایش لیست مدیران

💢!bots
نمایش لیست ربات های گروه

🎈!who
لیست تمامی اعضای گروه

💢!block
اخراج فرد از سوپر گروه
*اضافه شدن فرد به بلاک لیست*

🎈!ban
مسدود کردن فرد از سوپر گروه

💢!unban
حذف مسدود فرد از سوپر گروه

🎈!id
نمایش ایدی سوپر گروه
*برای نمایش ایدی یک یوزر: !id @username ویا ریپلای !id*

💢!id from
دریافت ایدی فردی که پیام از او فوروارد شده

🎈!kickme
اخراج شما از سوپر گروه
*Must be unblocked by owner or use join by pm to return*

💢!setowner
تنظیم صاحب گروه

🎈!promote [username|id]
تنظیم مدیر برای سوپر گروه

💢!demote [username|id]
خذف ک مدیر از سوپر گروه

🎈!setname
تنظیم نام سوپر گروه و قفل آن

💢!setphoto
تنظیم عکس گروه و قفل آن

🎈!setrules
تنظیم قوانین گروه

💢!setabout
تنظیم بیو در سوپر گروه

🎈!save [value] <text>
ذخیره در حافظه

💢!get [value]
نمایش متن ذخیره شده

🎈!newlink
ساخت لینک جدید (ربات باید سازنده گروه باشد)

💢!link
نمایش لینک سوپر گروه

🎈!rules
نمایش قوانین سوپر گروه

💢!lock [links|flood|spam|Arabic|member|rtl|sticker|contacts|strict]
قفل برخی تنظیمات سوپر گروه


🎈!unlock [links|flood|spam|Arabic|member|rtl|sticker|contacts|strict]
باز کردن برخی تنظیمات سوپر گروه


💢!mute [all|audio|gifs|photo|video|service]
بی صدا کردن برخی رسانه ها در سوپر گروه
*گزینه بی صدا شده در صورت قرار گرفتن در گروه پاک میشود

🎈!unmute [all|audio|gifs|photo|video|service]
با صدا کرد برخی رسانه ها در سوپر گروه
*گزینه بی صدا شده در صورت قرار گرفتن در گروه پاک نمیشود

💢!setflood [value]
تنظیم حساسیت به اسپم در سوپر گروه

🎈!settings
نمایش تنظیمات سوپر گروه

💢!muteslist
نمایش رسانه های بی صدا و باصدا

🎈!muteuser [username]
بی صدا کردن یک فرد
*فرد بی صدا شده تمامی پیام هایش پاک میشود
*فقط صاحب میتواند بی صدا کند/فقط مدیر و صاحب میتواند از حالت بی صدا در بیاورد

💢!mutelist
نمایس لیست افراد بی صدا

🎈!banlist
نمایش لیست افراد  بن شده

💢!clean [rules|about|modlist|mutelist]
پاک کردن قوانین/درباره/مدیران/لیست بی صدا
🎈!del
دلیت کردن یک پیام با ریپلای بر روی آن

💢!public [yes|no]
تنظیم حالت گروه 

🎈!res [username]
دریافت اطلاعات یک یوزرنیم


💢!log
دریافت اطلاعات گروه

**میتوانید از "#", "!", or "/" اول همه دستورات استفاده کنید

*فقط ادمین میتونه استفاده کنه از دستورات kick,ban,unban,newlink,setphoto,setname,lock,unlock,set rules,set about و settings 

*فقط صاحب میتواند از دستوات res, setowner, promote, demote, and log استفاده کند!

]],
  }
  serialize_to_file(config, './data/config.lua')
  print('saved config into ./data/config.lua')
end

function on_our_id (id)
  our_id = id
end

function on_user_update (user, what)
  --vardump (user)
end

function on_chat_update (chat, what)
  --vardump (chat)
end

function on_secret_chat_update (schat, what)
  --vardump (schat)
end

function on_get_difference_end ()
end

-- Enable plugins in config.json
function load_plugins()
  for k, v in pairs(_config.enabled_plugins) do
    print("Loading plugin", v)

    local ok, err =  pcall(function()
      local t = loadfile("plugins/"..v..'.lua')()
      plugins[v] = t
    end)

    if not ok then
      print('\27[31mError loading plugin '..v..'\27[39m')
	  print(tostring(io.popen("lua plugins/"..v..".lua"):read('*all')))
      print('\27[31m'..err..'\27[39m')
    end

  end
end

-- custom add
function load_data(filename)

	local f = io.open(filename)
	if not f then
		return {}
	end
	local s = f:read('*all')
	f:close()
	local data = JSON.decode(s)

	return data

end

function save_data(filename, data)

	local s = JSON.encode(data)
	local f = io.open(filename, 'w')
	f:write(s)
	f:close()

end


-- Call and postpone execution for cron plugins
function cron_plugins()

  for name, plugin in pairs(plugins) do
    -- Only plugins with cron function
    if plugin.cron ~= nil then
      plugin.cron()
    end
  end

  -- Called again in 2 mins
  postpone (cron_plugins, false, 120)
end

-- Start and load values
our_id = 0
now = os.time()
math.randomseed(now)
started = false


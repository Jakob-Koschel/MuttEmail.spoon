--- === MuttWizard ===
---
--- Thie plugin automatically syncs emails with mutt-wizard and shows the unread
--- count as a menubar item

local obj = {}

obj.name = "MuttWizard"
obj.version = "1.0"
obj.author = "https://github.com/Jakob-Koschel"
obj.homepage = "https://github.com/Jakob-Koschel/MuttWizard.spoon"
obj.license = "MIT - https://opensource.org/licenses/MIT"


function refreshEmail(whatToDoAfter)
  local task = hs.task.new('/bin/sh',
  function(err, stdOut, stdErr)
    whatToDoAfter(err, stdOut, stdErr)
    task = nil
  end,
  { '-c', 'mw -Y'})
  local env = task:environment()
  local path = env["PATH"]
  path = path..":/opt/homebrew/bin:/usr/local/bin"
  env["PATH"] = path
  task:setEnvironment(env)
  task:start()
end

-- update the menu bar
local function updateCount(count)
  if count > 0 then
    obj.menu:setTitle('📫 '..count)
  else
    obj.menu:setTitle('📪')
  end
end

local function onClick()
  checkEmailUnread()
end

local function checkEmailUnread()
  -- TODO: check how many emails are unread
  local task = hs.task.new('/bin/sh',
  function(err, stdOut, stdErr)
    new_mail_count = tonumber(stdOut:gsub("%s+", ""))
    updateCount(new_mail_count)
    task = nil
  end,
  { '-c', 'notmuch search tag:inbox AND tag:unread | wc -l'})
  local env = task:environment()
  local path = env["PATH"]
  path = path..":/opt/homebrew/bin:/usr/local/bin"
  env["PATH"] = path
  task:setEnvironment(env)
  task:start()
end

-- timer callback, fetch response
local function onInterval()
  refreshEmail(checkEmailUnread)
end


function obj:start(config)
  local interval = config.interval or 60

  -- create menubar (or restore it)
  if self.menu then
    self.menu:returnToMenuBar()
  else
    self.menu = hs.menubar.new():setClickCallback(onClick)
  end

  -- set timer to fetch periodically
  self.timer = hs.timer.new(interval, onInterval)
  self.timer:start()

  -- fetch immediately, too
  checkEmailUnread(0)
  onInterval()

  self.watcher = hs.caffeinate.watcher.new(function(eventType)
    if (eventType == hs.caffeinate.watcher.screensDidWake or
      eventType == hs.caffeinate.watcher.systemDidWake or
      eventType == hs.caffeinate.watcher.screensDidUnlock) and not refreshing then
      -- refresh all email accounts
      refreshEmail(checkEmailUnread)
    end
  end)
  self.watcher:start()

  hs.urlevent.bind("MuttWizardCheckEmailUnread", function(eventName, params)
    checkEmailUnread()
  end)

  return self
end


function obj:stop(config)
  self.menu:removeFromMenuBar()
  self.timer:stop()
  self.watcher:stop()

  return self
end


function obj:init()
  -- currently no init required
end

return obj

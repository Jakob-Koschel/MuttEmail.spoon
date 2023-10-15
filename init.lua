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
obj.count = 0
obj.auth_required = false

local function executeCommand(command, callbackFn)
  local task = hs.task.new('/bin/sh',
  callbackFn,
  { '-c', command})
  local env = task:environment()
  local path = env["PATH"]
  path = path..":/opt/homebrew/bin:/usr/local/bin"
  env["PATH"] = path
  task:setEnvironment(env)
  task:start()
end


function refreshEmail(whatToDoAfter)
  executeCommand('mw -Y',
  function(err, stdOut, stdErr)
    whatToDoAfter(err, stdOut, stdErr)
    task = nil
  end)
end

-- update the menu bar
local function updateTitle()
  count = obj.count
  title = ''
  if count > 0 then
    title = '📫 '..count
  else
    title = '📪'
  end
  if obj.auth_required then
    title = title .. ' ⚠️ '
  end
  obj.menu:setTitle(title)
end

local function checkEmailUnread()
  -- TODO: check how many emails are unread
  executeCommand("notmuch search tag:inbox AND tag:unread AND folder:'/INBOX$/' | wc -l",
  function(err, stdOut, stdErr)
    numStr = stdOut:gsub("%s+", "")
    obj.count = tonumber(numStr)
    updateTitle()
    task = nil
  end)
end

local function triggerPinentryUnlock()
  -- trigger authenticating
  executeCommand("echo 'test' | gpg --clearsign",
  function(err, stdOut, stdErr)
    if err == 0 then
      obj.auth_required = false
    else
      obj.auth_required = true
    end
    updateTitle()
    task = nil
  end)
end

local function checkIfPinentryUnlockRequired()
  executeCommand("echo 'test' | gpg --pinentry-mode=cancel --clearsign",
  function(err, stdOut, stdErr)
    if err == 0 then
      obj.auth_required = false
    -- elseif obj.auto_auth then
    --   triggerPinentryUnlock()
    else
      obj.auth_required = true
    end
    task = nil
  end)
end

local function getDuration(startTime)
  local p = "%a+ (%a+) *(%d+) (%d+):(%d+):(%d+) (%d+)"
  startTime = 'Sun Jun  4 16:04:09 2023'
  local month, day, hour, min, sec, year = startTime:match(p)
  local MON = {Jan=1, Feb=2, Mar=3, Apr=4, May=5, Jun=6, Jul=7, Aug=8, Sep=9, Oct=10, Nov=11, Dec=12}
  local month=MON[month]
  local startSeconds = os.time({day=day, month=month, year=year, hour=hour, min=min, sec=sec, isdst=false})
  local currentSeconds = os.time()

  local t = os.date("*t", now)
  if t.isdst then
    startSeconds =  startSeconds - (60 * 60)
  end

  return currentSeconds - startSeconds
end

local function checkIfMbsyncStuck()
  executeCommand("pgrep -x mbsync",
    function(err, stdOut, stdErr)
      for pid in stdOut:gmatch("(%d+)\n") do
        executeCommand("ps -o lstart= -p " .. pid,
          function(err, stdOut, stdErr)
            local duration = getDuration(stdOut:gsub("\n$", ""))

            local durationHours = duration / 3600
            if durationHours >= 1 then
              executeCommand("killall mbsync")
            end
          end)
      end
    end)
end

local function onClick()
  checkEmailUnread()
  if obj.auth_required then
    triggerPinentryUnlock()
  end
end

-- timer callback, fetch response
local function onInterval()
  checkIfMbsyncStuck()
  checkIfPinentryUnlockRequired()
  refreshEmail(checkEmailUnread)
end


function obj:start(config)
  local interval = config.interval or 60
  self.auto_auth = config.auto_auth or false

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

  return self
end


function obj:stop(config)
  self.menu:removeFromMenuBar()
  self.timer:stop()
  self.watcher:stop()

  return self
end


function obj:init()
  -- save function on object to call from command line:
  -- hs -c "spoon.MuttWizard.checkEmailUnread()"
  self.checkEmailUnread = checkEmailUnread
end

return obj

--- === MuttEmail ===
---
--- Thie plugin automatically syncs emails with mutt-wizard and shows the unread
--- count as a menubar item

local obj = {}

obj.name = "MuttEmail"
obj.version = "1.0"
obj.author = "https://github.com/Jakob-Koschel"
obj.homepage = "https://github.com/Jakob-Koschel/MuttEmail.spoon"
obj.license = "MIT - https://opensource.org/licenses/MIT"

-- create the icon
-- http://xqt2.com/asciiIcons.html
local iconAscii = [[ASCII:
............
............
....AD......
..F.....PQ..
..I.........
..........G.
..........H.
.K..........
.N..........
.........L..
..BC.....M..
......SR....
............
............
]]

local icon = hs.image.imageFromASCII(iconAscii)

-- on click, open slack
local function onClick()
  print("onClick...")
end


-- update the menu bar
local function updateCount(count)
  if count > 0 then
    obj.menu:setTitle(count)
  else
    obj.menu:setTitle('0')
  end
end


-- timer callback, fetch response
local function onInterval()
  print("onInterval...")
end


function obj:start(config)
  local interval = config.interval or 60

  -- create menubar (or restore it)
  if self.menu then
    self.menu:returnToMenuBar()
  else
    self.menu = hs.menubar.new():setClickCallback(onClick):setIcon(icon)
  end

  -- set timer to fetch periodically
	self.timer = hs.timer.new(interval, onInterval)
	self.timer:start()

  -- fetch immediately, too
	updateCount(0)
	onInterval()

	return self
end


function obj:stop(config)
  self.menu:removeFromMenuBar()
  self.timer:stop()

  return self
end


function obj:init()
  -- currently no init required
end

return obj

-- Builds a layered .aseprite (one layer per part slot) from exported part sheets.
-- aseprite -b --script-param layers=<layers.txt> --script-param anims=<anims.txt> --script-param out=<file.aseprite> --script layered.lua
local W, H, COLS = 254, 138, 9
local anims = {}  -- lines of name|frames|fps, in sheet order
for line in io.lines(app.params["anims"]) do
  local n, c, f = line:match("^(.-)|(%d+)|([%d%.]+)$")
  if n then table.insert(anims, { n, tonumber(c), tonumber(f) }) end
end
local total = 0
for _, a in ipairs(anims) do total = total + a[2] end

local list = {}
for line in io.lines(app.params["layers"]) do
  local name, path = line:match("^(.-)|(.+)$")
  if name then table.insert(list, { name = name, path = path }) end
end

local spr = Sprite(W, H, ColorMode.RGB)
for i = 2, total do spr:newEmptyFrame() end
local k = 0
for _, a in ipairs(anims) do
  for i = 1, a[2] do
    k = k + 1
    spr.frames[k].duration = 1 / a[3]
  end
end

local first = spr.layers[1]
for idx, item in ipairs(list) do
  local layer = (idx == 1) and first or spr:newLayer()
  layer.name = item.name
  local sheet = Image{ fromFile = item.path }
  for f = 0, total - 1 do
    local img = Image(W, H, ColorMode.RGB)
    img:drawImage(sheet, Point(-(f % COLS) * W, -math.floor(f / COLS) * H))
    if not img:isEmpty() then spr:newCel(layer, spr.frames[f + 1], img, Point(0, 0)) end
  end
end

local s = 1
for _, a in ipairs(anims) do
  local t = spr:newTag(s, s + a[2] - 1)
  t.name = a[1]
  s = s + a[2]
end
spr:saveAs(app.params["out"])
print("layers: " .. #spr.layers .. ", frames: " .. #spr.frames)

--[[pod_format="raw",created="2024-10-14 18:50:00",modified="2024-10-14 19:29:59",revision=136]]
if not import then 
  import = function(path) 
    new_path, _ = string.gsub(path, "%.%./", "")
    return load(fetch("tinta/source/" .. new_path .. ".lua"))()
  end 
end

table.sort = function (t, cmp)
 local n = #t
 local i, j, temp
 local lower = flr(n / 2) + 1
 local upper = n
 while 1 do
  if lower > 1 then
   lower -= 1
   temp = t[lower]
  else
   temp = t[upper]
   t[upper] = t[1]
   upper -= 1
   if upper == 1 then
    t[1] = temp
    return
   end
  end

  i = lower
  j = lower * 2
  while j <= upper do
   if j < upper and cmp(t[j], t[j+1]) then
    j += 1
   end
   if cmp(temp, t[j]) then
    t[i] = t[j]
    i = j
    j += i
   else
    j = upper + 1
   end
  end
  t[i] = temp
 end
end

picotron = true
dump = import('libs/dump')
compat = import("compat/lua54")
Story = import("engine/story")

return Story

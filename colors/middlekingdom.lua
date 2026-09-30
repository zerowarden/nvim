local prefix = "middlekingdom."
for mod in pairs(package.loaded) do
  if mod:sub(1, #prefix) == prefix then package.loaded[mod] = nil end
end
require("middlekingdom").load()

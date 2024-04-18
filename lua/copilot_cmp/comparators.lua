local comparators = {}

comparators.score = function(entry1, entry2)
  local diff = (entry1.completion_item.copilot and 1.2 * entry1.score or entry1.score)
    - (entry2.completion_item.copilot and 1.2 * entry2.score or entry2.score)
  if diff < 0 then
    return false
  end
  return diff > 0 or nil
end

comparators.prioritize = function(entry1, entry2)
  if entry1.completion_item.copilot and not entry2.completion_item.copilot then
    return true
  elseif entry2.completion_item.copilot and not entry1.completion_item.copilot then
    return false
  end
end

return comparators

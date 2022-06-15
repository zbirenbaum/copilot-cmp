local comparators = {}

comparators.score = function (entry1, entry2)
  if entry1.score and entry2.score then
    return entry1.score > entry2.score
  end
end

comparators.prioritize = function (entry1, entry2)
  if entry1.copilot and not entry2.copilot then
    return true
  elseif entry2.copilot and not entry1.copilot then
    return false
  end
end

return comparators

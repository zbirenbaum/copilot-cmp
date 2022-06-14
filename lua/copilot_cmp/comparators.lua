local comparators = {}

comparators.copilot = function (entry1, entry2)

  local score = function ()
    if entry1.score and entry2.score then
      return entry1.score > entry2.score
    end
  end

  if entry1.copilot and not entry2.copilot then -- always place copilot at top of entries
    return true
  elseif entry2.copilot and not entry1.copilot then
    return false
  elseif entry1.copilot and entry2.copilot then
    return score() -- if score not availiable is nil
  end
end

return comparators

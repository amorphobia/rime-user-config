local function filter(input, env)
  for cand in input:iter() do
    local delimiter = string.find(cand.text, "`[^`]*$")
    if delimiter == nil then
      yield(cand)
    else
      local word = string.sub(cand.text, 1, delimiter - 1)
      local comment = string.sub(cand.text, delimiter + 1)
      if word == "" or comment == "" then
        yield(cand)
      else
        local original_comment = cand:get_genuine().comment
        if word:sub(1,1) ~= "$" then
          yield(Candidate(cand.type, cand.start, cand._end, word, original_comment .. comment))
        else
          yield(Candidate(word, cand.start, cand._end, original_comment .. comment, ""))
        end
      end
    end
  end
end

return filter

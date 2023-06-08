-- Split Filter
-- Copyright (C) 2023  Xuesong Peng <pengxuesong.cn@gmail.com>

-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.

-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.

-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.

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

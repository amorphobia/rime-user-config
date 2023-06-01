local function translator(input, seg)
    local delimiter = string.find(input, "`")
    if delimiter ~= nil then
        local input_code = string.sub(input, delimiter + 1)
        local codepoint = tonumber(input_code, 16)
        if codepoint ~= nil then
            local cand = Candidate("unicode", seg.start, seg._end, utf8.char(codepoint), " Unicode")
            -- input_code = string.format("%04s", input_code)
            -- string.format not working in Hamster
            local num_prefix = 4 - string.len(input_code)
            if num_prefix > 0 then
                input_code = string.rep("0", num_prefix) .. input_code
            end
            cand.preedit = "U+" .. string.upper(input_code)
            yield(cand)
        end
    end
end

return translator

local base64 = {

}
base64.characters = '"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
function base64.encode(input)
	local res = {}
	local pad = ""

	local rem = #input % 3
	if rem > 0 then
		pad = string.rep("=", 3 - rem)
		input = input..string.rep("\0", 3 - rem)
	end

	for i = 1, #input, 3 do
		local bytea = string.byte(input, i)
		local byteb = string.byte(input, i + 1)
		local bytec = string.byte(input, i + 2)

		local val1 = math.floor(bytea / 4)
		local val2 = ((bytea % 4) * 16) + math.floor(byteb / 16)
		local val3 = ((byteb % 16) * 4) + math.floor(bytec / 64)
		local val4 = bytec % 64

		res[#res + 1] = base64.characters:sub(val1 + 1, val1 + 1)
		res[#res + 1] = base64.characters:sub(val2 + 1, val2 + 1)
		res[#res + 1] = base64.characters:sub(val3 + 1, val3 + 1)
		res[#res + 1] = base64.characters:sub(val4 + 1, val4 + 1)
	end

	if pad ~= "" then
		for i = 1, #pad do
			res[#res - (i - 1)] = "="
		end
	end

	return table.concat(res)
end

function base64.decode(input)
	input = input:gsub("[^A-Za-z0-9+/=]", "")
	local res = {}
	local bytes = {}

	for i = 1, #input, 4 do
		local c1 = input:sub(i, i)
		local c2 = input:sub(i + 1, i + 1)
		local c3 = input:sub(i + 2, i + 2)
		local c4 = input:sub(i + 3, i + 3)

		local v1 = base64.characters:find(c1, 1, true)
		local v2 = base64.characters:find(c2, 1, true)
		local v3 = base64.characters:find(c3, 1, true)
		local v4 = base64.characters:find(c4, 1, true)

		if not v1 or not v2 then break end
		v1, v2 = v1 - 1, v2 - 1
		v3 = v3 and (v3 - 1) or 0
		v4 = v4 and (v4 - 1) or 0

		local b1 = (v1 * 4) + math.floor(v2 / 16)
		local b2 = ((v2 % 16) * 16) + math.floor(v3 / 4)
		local b3 = ((v3 % 4) * 64) + v4

		bytes[#bytes + 1] = string.char(b1)
		if c3 ~= "=" then bytes[#bytes + 1] = string.char(b2) end
		if c4 ~= "=" then bytes[#bytes + 1] = string.char(b3) end
	end

	return table.concat(bytes)
end

return base64
local Headers = ... or {}
local vape = shared.vape
local isfile = isfile or function(file)
	local suc, res = pcall(function() 
		return readfile(file) 
	end)
	return suc and res ~= nil and res ~= ''
end
local function downloadFile(path, func)
	if not isfile(path) then
		local suc, res = pcall(function() 
			return game:HttpGet('https://raw.githubusercontent.com/wrj80z/OnyxV4/'..readfile('onyx/profiles/commit.txt')..'/'..select(1, path:gsub('onyx/', '')), true) 
		end)
		if not suc or res == '404: Not Found' then 
			error(res) 
		end
		if path:find('.lua') then 
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res 
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end

vape.Place = 6872274481
if isfile('onyx/games/'..vape.Place..'.lua') then
	loadstring(readfile('onyx/games/'..vape.Place..'.lua'), 'bedwars')(Headers)
else
	if not shared.VapeDeveloper then
		local suc, res = pcall(function() 
			return game:HttpGet('https://raw.githubusercontent.com/wrj80z/OnyxV4/'..readfile('onyx/profiles/commit.txt')..'/games/'..vape.Place..'.lua', true) 
		end)
		if suc and res ~= '404: Not Found' then
			loadstring(downloadFile('onyx/games/'..vape.Place..'.lua'), 'bedwars')(Headers)
		end
	end
end
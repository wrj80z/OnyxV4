--!nocheck
local Headers = ... or {}
Headers.Key = Headers.Key or rawget(getfenv(), "key") or "NIGGA-KEY"
repeat task.wait() until game:IsLoaded()
if shared.vape then shared.vape:Uninject() end
local cloneref = cloneref or function(obj)
    return obj
end
local isfile = isfile or function(file)
    local suc, res = pcall(function()
        return pcall(readfile, file)
    end)
    return suc and res ~= nil and res ~= ''
end
local delfile = delfile or function(file)
    writefile(file, '')
end
local clonefunction = clonefunction or function(func)
    return (typeof(func) == 'function' and func or nil)
end

local vape = nil
local loadstr = clonefunction(loadstring)
getgenv().oldloadstring = loadstr
local loadstring = function(...)
	local res, err = loadstr(...)
	if err and vape then
        vape:CreateNotification('Vape', `Failed to load: {err} | Storing packets..`, 30, 'alert')
        --todo store packet to server
    elseif err and not vape then
        warn(err)
	end
	return res
end
local playersService = cloneref(game:GetService('Players'))
local httpService = cloneref(game:GetService('HttpService'))
local lplr = playersService.LocalPlayer

local direct = function()
    local body = httpService:JSONEncode({
        nonce = httpService:GenerateGUID(false),
        args = {
            invite = {code = '2E92Smnx4W'},
            code = '2E92Smnx4W'
        },
        cmd = 'INVITE_BROWSER'
    })

    local function req()
        pcall(function()
            request({
                Method = 'POST',
                Url = 'http://127.0.0.1:6463/rpc?v=1',
                Headers = {
                    ['Content-Type'] = 'application/json',
                    Origin = 'https://discord.com'
                },
                Body = body
            })
        end)
    end
    task.delay(lplr:GetNetworkPing(), function()
        req()
        task.wait(lplr:GetNetworkPing())
        req()
    end)
end

task.spawn(function()
    if not isfile('onyx/newuser.txt') then
        writefile('onyx/newuser.txt', 'false')
        direct()
    end
end)

local downloader = getgenv().downloader

local function downloadFile(path, func)
    if not isfile(path) then
        if not Headers.Closet and downloader then
            downloader.Text = `Downloading {path}`
        end
        local suc, res =  pcall(function()
            return game:HttpGet(`https://raw.githubusercontent.com/wrj80z/OnyxV4/{readfile('onyx/profiles/commit.txt')}/{select(1, path:gsub('onyx/', ''))}`, true)
        end)
        if not suc or res == '404: Not Found' then
            error(res)
        end
        if path:find('.lua') then
            res = "--This watermark is used to delete the file if it's cached, remove it to make the file persist after vape updates.\n"..res
        end
        writefile(path, res)
        task.wait(lplr:GetNetworkPing()) -- funny
        if downloader then
            downloader.Text = ''
        end
    end
    return (func or readfile)(path)
end

local function finishLoading()
    vape.Init = nil
    vape:Load()
    task.spawn(function()
        local tme = (10 + lplr:GetNetworkPing())
        repeat
            vape:Save()
            task.wait(tme)
        until not vape.Loaded
    end)
    local tpSes = nil
    vape:Clean(playersService.LocalPlayer.OnTeleport:Connect(function(state)
        if (not tpSes) and (not shared.VapeIndependent) then
            tpSes = true
            local tpScript = [[
                if shared.VapeDeveloper then
                    loadstring(readfile('onyx/main.lua'), 'main')(config)
                    local key = '_key'
                    print(key)
                else
                    loadstring(game:HttpGet("https://raw.githubusercontent.com/wrj80z/OnyxV4/main/init.lua", true))(config)                    local key = '_key'
                    print(key)
                    -- todo make it get to the api w key
                end
            ]]
            local tpConfig = httpService:JSONEncode(Headers)
            tpConfig = tpConfig:gsub('":true', "=true"):gsub('{"', '{')
            tpConfig = tpConfig:gsub('":false', "=false"):gsub('{"', '{')
			tpConfig = tpConfig:gsub(',"', ','):gsub('":', '=')
			tpConfig = tpConfig:gsub('%[', '{'):gsub('%]', '}')
			tpScript = tpScript:gsub('_key', tostring(Headers.Key or 'NIGGA-KEY'))
			tpScript = tpScript:gsub('config', tpConfig)
			if shared.VapeDeveloper then
				tpScript = 'shared.VapeDeveloper = true\n'..tpScript
			end
			if shared.VapeCustomProfile then
				tpScript = 'shared.VapeCustomProfile = "'..shared.VapeCustomProfile..'"\n'..tpScript
			end
			queue_on_teleport(tpScript)
        end
    end))

    if not shared.vapereload then
        if not vape.Categories then return end
        if vape.Categories.Main.Options['GUID bind indicator'].Enabled then
            if getgenv().role:find('HWID') then
                vape:CreateNotification('Onyx', 'HWID MISMATCH?, Go to the script panel and reset your hwid.', 30, 'warning')
                getgenv().role = ''
                task.wait(0.1 + lplr:GetNetworkPing())
            end
            vape:CreateNotification('Finished Loading!', (getgenv().name and `Authenticated as {getgenv().name} with {getgenv().role}, ` or '').. (vape.VapeButton and 'Press the button in the top right' or 'Press '..table.concat(vape.Keybind, ' + '):upper())..' to open GUI', 5)
            task.delay(1 + lplr:GetNetworkPing(), function()
				if shared.update then
					vape:CreateNotification('Onyx', `Script has updated from {shared.update} to {readfile('onyx/profiles/commit.txt')}`, 15)
				end
            end)
        end
    end
end

if not isfile('onyx/profiles/gui.txt') then
	writefile('onyx/profiles/gui.txt', 'new')
end
local gui = readfile('onyx/profiles/gui.txt') or 'new'

if not isfolder('onyx/assets/'..gui) then
	makefolder('onyx/assets/'..gui)
end
if not isfile('onyx/profiles/commit.txt') then
	writefile('onyx/profiles/commit.txt', 'main')
end

vape = loadstring(downloadFile('onyx/guis/'..gui..'.lua'), 'gui')(Headers)
print(gui)
print(vape)
shared.vape = vape

if not shared.VapeIndependent then
	loadstring(downloadFile('onyx/games/universal.lua'), 'universal')(Headers)
	if isfile('onyx/games/'..game.PlaceId..'.lua') then
		loadstring(readfile('onyx/games/'..game.PlaceId..'.lua'), tostring(game.PlaceId))(Headers)
	else
		if not shared.VapeDeveloper then
			local suc, res = pcall(function()
				return game:HttpGet('https://raw.githubusercontent.com/wrj80z/OnyxV4/'..readfile('onyx/profiles/commit.txt')..'/games/'..game.PlaceId..'.lua', true)
			end)
			if suc and res ~= '404: Not Found' then
				loadstring(downloadFile('onyx/games/'..game.PlaceId..'.lua'), tostring(game.PlaceId))(Headers)
			end
		end
	end
	finishLoading()
else
	vape.Init = finishLoading
	return vape
end

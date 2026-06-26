--!nocheck
local Headers = ... or {}
Headers.Key = rawget(getfenv(), "key") or Headers.Key or "NIGGA-KEY"

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
    pcall(writefile, file, '')
end

local playersService = cloneref(game:GetService('Players'))
local lplr = playersService.LocalPlayer

local function downloaderFUNC()
    if getgenv().downloader then
        return getgenv().downloader
    end
    local parent = gethui and gethui() or cloneref(game:GetService("CoreGui"))
    local gui = Instance.new("ScreenGui")
    gui.Parent = parent
    local d = Instance.new("TextLabel")
    d.Parent = gui
    d.Size = UDim2.new(1, 0, 0, 40)
    d.BackgroundTransparency = 1
    d.TextStrokeTransparency = 0
    d.TextSize = 20
    d.TextColor3 = Color3.new(1,1,1)
    d.Font = Enum.Font.Arial
    d.Text = ""
    getgenv().downloader = d
    return d
end

local downloader = downloaderFUNC()

local function downloadFile(path, func)
    if not pcall(isfile, path) then
        if not Headers.Closet then
            downloader.Text = `Downloading {path}`
        end
        local suc, res =  pcall(function()
            return game:HttpGet(`https://raw.githubusercontent.com/wrj80z/OnyxV4/{readfile('onyx/profiles/commit.txt')}/{select(1, path:gsub('onyx/', ''))}`, true)
        end)
        if not suc or res:find('404') then
            error(res)
        end
        if path:find('.lua') then
            res = "--This watermark is used to delete the file if it's cached, remove it to make the file persist after vape updates.\n"..res
        end
        pcall(writefile, path, res)
        downloader.Text = ''
    end
    return (func or readfile)(path)
end

local function wipeFolder(path)
    if not pcall(isfolder, path) then return end
    for _, file in pcall(listfiles, path) do
        if file:find('init') then continue end
        if file:find('profile') then continue end
        if pcall(isfile, file) then
            pcall(delfile, file)
        elseif pcall(isfolder, file) then
            wipeFolder(file)
        end
    end
end

for _, folder in {'onyx', 'onyx/games', 'onyx/profiles', 'onyx/assets', 'onyx/libraries', 'onyx/guis'} do
    if not isfolder(folder) then
        if not Headers.Closet then
            downloader.Text = `Downloading {folder}`
        end
        pcall(makefolder, folder)
        downloader.Text = ``
    end
end

if not shared.VapeDeveloper then
    local com = Headers.Commit or nil
    if not com then
        local _, res = pcall(function()
            return game:HttpGet('https://github.com/wrj80z/OnyxV4')
        end)
        com = res:find('currentOid')
        com = com and res:sub(com + 13, com + 52) or nil
        com = com and #com == 40 and com or 'main'
    elseif com == 'main' or (pcall(isfile, 'onyx/profiles/commit.txt') and pcall(readfile, 'onyx/profiles/commit.txt') or '') ~= com then
        if com ~= 'main' and pcall(isfile, 'onyx/profiles/commit.txt') then
            shared.update = pcall(readfile, 'onyx/profiles/commit.txt')
        end
        wipeFolder('onyx')
        wipeFolder('onyx/games')
        wipeFolder('onyx/guis')
        wipeFolder('onyx/libraries')
    end
    pcall(writefile, 'onyx/profiles/commit.txt', com)
end

downloader.Text = ''
local dwlmain, dwlres = pcall(downloadFile, 'onyx/main.lua')
print(dwlmain, dwlres)
return loadstring(dwlres, 'main')(Headers)

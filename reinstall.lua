--!nonstrict
local Headers = ... or {}

local cloneref = cloneref or function(res: any)
    return (res or nil)
end

local StarterGui: StarterGui = cloneref(game:GetService('StarterGui'))
local Players: Players = cloneref(game:GetService('Players'))
local lplr: LocalPlayer = Players.LocalPlayer

pcall(function()
    if isfolder('onyx') then
        if Headers.Force then
            pcall(delfolder,'onyx')
        else
            for _, fldr in {'libraries', 'assets', 'guis', 'games'} do
                pcall(delfolder, `onyx/{fldr}`)
            end
            for _, files in {'init', 'main'} do
                pcall(delfile, `onyx/{files}.lua`)
            end
        end
    end
end)

StarterGui:SetCore('SendNotification', {
    Title = 'Onyx',
    Text = Headers.Force and 'Onyx has been successfully deleted. Everything has been wiped. Reinject to continue.' or 'Onyx has been successfully reinstalled. Rejoin the game to apply the changes.',
    Duration = Headers.Force and 10 + lplr:GetNetworkPing() or 20 + lplr:GetNetworkPing()
})
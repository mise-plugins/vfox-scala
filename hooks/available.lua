local util = require("util")
local http = require("http")

--- Return all available versions provided by this plugin
--- @param ctx table Empty table used as context, for future extension
--- @return table Descriptions of available versions and accompanying tool descriptions
function PLUGIN:Available(ctx)
    local resp, err = http.get({
        url = util.SEARCH_URL,
    })
    if err ~= nil or resp.status_code ~= 200 then
        return {}
    end

    local htmlBody = resp.body
    local htmlContent = [[]] .. htmlBody .. [[]]
    local versions = {}

    for version in htmlContent:gmatch('<a href="/download/([^"]-)%.html">Scala [^<]-</a>') do
        if not version:find("develop", 1, true) then
            table.insert(versions, version)
        end
    end

    util:sort_versions(versions)

    local result = {}
    for i = #versions, 1, -1 do
        table.insert(result, { version = versions[i], note = "" })
    end

    return result
end

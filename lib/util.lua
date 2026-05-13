local util = {}
local http = require("http")

util.SEARCH_URL = "https://www.scala-lang.org/download/all.html"
util.SCALA3_DOWNLOAD_URL = "https://github.com/scala/scala3/releases/download/%s/scala3-%s.%s"
util.SCALA2_DOWNLOAD_PAGE_URL = "https://scala-lang.org/download/%s.html"

function util:version_weight(version)
    local weighted = version:gsub("%+.*$", ""):gsub("^v", "")
    if weighted:find("%.") and not weighted:find("[^%d%.]") then
        weighted = weighted .. "-stable"
    end

    -- Keep ordering aligned with the asdf Scala plugin's version_weight sorter.
    local replacements = {
        { pattern = "([^%a])dev%.?([^%a]?)", repl = "%1.10.%2" },
        { pattern = "([^%a])alpha%.?([^%a]?)", repl = "%1.20.%2" },
        { pattern = "([^%a])a%.?([^%a]?)", repl = "%1.20.%2" },
        { pattern = "([^%a])beta%.?([^%a]?)", repl = "%1.30.%2" },
        { pattern = "([^%a])b%.?([^%a]?)", repl = "%1.30.%2" },
        { pattern = "([^%a])rc%.?([^%a]?)", repl = "%1.40.%2" },
        { pattern = "([^%a])RC%.?([^%a]?)", repl = "%1.40.%2" },
        { pattern = "([^%a])stable%.?([^%a]?)", repl = "%1.50.%2" },
        { pattern = "([^%a])pl%.?([^%a]?)", repl = "%1.60.%2" },
        { pattern = "([^%a])patch%.?([^%a]?)", repl = "%1.70.%2" },
        { pattern = "([^%a])p%.?([^%a]?)", repl = "%1.70.%2" },
    }

    for _, replacement in ipairs(replacements) do
        weighted = weighted:gsub(replacement.pattern, replacement.repl)
    end

    return weighted:gsub("%.+", "."):gsub("%.$", ""):gsub("%-%.", ".")
end

function util:tokenize_version(version)
    local tokens = {}
    local i = 1
    while i <= #version do
        local char = version:sub(i, i)
        local token
        if char:match("%d") then
            token = version:match("^%d+", i)
            table.insert(tokens, { type = "number", value = tonumber(token), raw = token })
        else
            token = version:match("^%D+", i)
            table.insert(tokens, { type = "string", value = token, raw = token })
        end
        i = i + #token
    end

    return tokens
end

function util:version_less_than(v1, v2)
    local v1_tokens = util:tokenize_version(util:version_weight(v1))
    local v2_tokens = util:tokenize_version(util:version_weight(v2))

    for i = 1, math.max(#v1_tokens, #v2_tokens) do
        local v1_token = v1_tokens[i]
        local v2_token = v2_tokens[i]
        if v1_token == nil then
            return true
        elseif v2_token == nil then
            return false
        elseif v1_token.type == v2_token.type then
            if v1_token.value ~= v2_token.value then
                return v1_token.value < v2_token.value
            elseif v1_token.raw ~= v2_token.raw then
                return #v1_token.raw < #v2_token.raw
            end
        elseif v1_token.type == "number" then
            return true
        else
            return false
        end
    end

    return false
end

function util:sort_versions(versions)
    table.sort(versions, function(v1, v2)
        return util:version_less_than(v1, v2)
    end)
end

function util:getArchiveSuffix()
    local suffixType = ""
    if RUNTIME.osType == "windows" then
        suffixType = "zip"
    else
        suffixType = "tar.gz"
    end

    return suffixType
end

function util:getScala2DownloadUrl(version)
    local resp, err = http.get({
        url = util.SCALA2_DOWNLOAD_PAGE_URL:format(version),
    })
    if err ~= nil or resp.status_code ~= 200 then
        error("failed to resolve Scala download page for " .. version)
    end

    local linkId = "link%-main%-unixsys"
    if RUNTIME.osType == "windows" then
        linkId = "link%-main%-windows"
    end

    local downloadUrl = resp.body:match('id="#' .. linkId .. '" href="([^"]+)"')
    if downloadUrl == nil then
        error("failed to find Scala archive URL for " .. version)
    end

    if RUNTIME.osType == "windows" then
        downloadUrl = downloadUrl:gsub("%.msi$", ".zip")
    end

    return downloadUrl
end

function util:getDownloadUrl(version)
    if version:match("^3%.") then
        local suffixType = util:getArchiveSuffix()
        return util.SCALA3_DOWNLOAD_URL:format(version, version, suffixType)
    end

    return util:getScala2DownloadUrl(version)
end

return util

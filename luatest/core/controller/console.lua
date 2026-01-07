---@namespace Luatest

---@export namespace
local export = {}

---@type table<string, string[]>
local stdoutByTestId = {}

function export.reset()
    stdoutByTestId = {}
end

---@param testId string
---@param chunk string
function export.appendStdout(testId, chunk)
    if type(testId) ~= "string" or testId == "" then
        return
    end
    if type(chunk) ~= "string" or chunk == "" then
        return
    end

    local list = stdoutByTestId[testId]
    if not list then
        list = {}
        stdoutByTestId[testId] = list
    end
    list[#list + 1] = chunk
end

---@param testId string
---@return string?
function export.consumeStdout(testId)
    if type(testId) ~= "string" or testId == "" then
        return nil
    end

    local list = stdoutByTestId[testId]
    if not list then
        return nil
    end
    stdoutByTestId[testId] = nil

    return table.concat(list)
end

---@param testId string
---@return boolean
function export.hasStdout(testId)
    local list = stdoutByTestId[testId]
    return type(list) == "table" and list[1] ~= nil
end

return export

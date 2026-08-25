-- VOLT26 utility bootstrap.
--
-- This file loads before SL_Init.lua and ThemePrefs, so it exposes one temporary
-- bootstrap namespace. SL_Init.lua publishes the same table as VOLT26.Util.

VOLT26Utility = {}

function VOLT26Utility.TableToString(value, name, indent)
	local visited = {}
	local render

	render = function(current, key, spacing, path)
		local id = not path and key or type(key) ~= "number" and tostring(key) or "[" .. key .. "]"
		local tag = spacing .. id .. " = "
		local output = {}

		if type(current) == "table" then
			if visited[current] then
				output[#output + 1] = tag .. "{} -- " .. visited[current] .. " (self reference)"
			else
				visited[current] = path and (path .. "." .. id) or id
				if next(current) then
					output[#output + 1] = tag .. "{"
					for childKey, childValue in pairs(current) do
						output[#output + 1] = render(childValue, childKey, spacing .. "|    ", visited[current])
					end
					output[#output + 1] = spacing .. "}"
				else
					output[#output + 1] = tag .. "{}"
				end
			end
		else
			local rendered = type(current) ~= "number" and type(current) ~= "boolean"
				and '"' .. tostring(current) .. '"' or tostring(current)
			output[#output + 1] = tag .. rendered
		end

		return table.concat(output, "\n")
	end

	return render(value, name or "Value", indent or "")
end

function VOLT26Utility.SystemMessage(value, duration, stack)
	local message = type(value) == "table" and VOLT26Utility.TableToString(value) or tostring(value)
	MESSAGEMAN:Broadcast("SystemMessage", {Message=message, Duration=duration, Stack=stack})
	Trace(message)
end

function VOLT26Utility.Range(startValue, stopValue, stepValue)
	if startValue == nil then return nil end
	if stopValue == nil then
		stopValue = startValue
		startValue = 1
	end

	local step = stepValue or 1
	if step == 0 then return {} end
	if step > 0 and startValue > stopValue then step = -step end

	local result = {}
	for value = startValue, stopValue, step do result[#result + 1] = value end
	return result
end

function VOLT26Utility.Stringify(values, formatString)
	if values == nil then return nil end
	local result = {}
	for _, value in ipairs(values) do
		result[#result + 1] = type(value) == "number" and formatString
			and formatString:format(value) or tostring(value)
	end
	return result
end

function VOLT26Utility.FindIndex(needle, haystack)
	if type(haystack) ~= "table" then return nil end
	for index = 1, #haystack do
		if needle == haystack[index] then return index end
	end
	return nil
end

function VOLT26Utility.Map(transform, values)
	local result = {}
	for index, value in ipairs(values or {}) do result[index] = transform(value) end
	return result
end

function VOLT26Utility.Deduplicate(values)
	local seen = {}
	local result = {}
	for _, value in ipairs(values or {}) do
		if not seen[value] then
			seen[value] = true
			result[#result + 1] = value
		end
	end
	return result
end

-- Early-load and unassessed-screen adapters. Accepted VOLT26 code should use
-- VOLT26.Util after SL_Init.lua has attached the bootstrap namespace.
TableToString = VOLT26Utility.TableToString
SM = VOLT26Utility.SystemMessage
range = VOLT26Utility.Range
stringify = VOLT26Utility.Stringify
FindInTable = VOLT26Utility.FindIndex
map = VOLT26Utility.Map
deduplicate = VOLT26Utility.Deduplicate

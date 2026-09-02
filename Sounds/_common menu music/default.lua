local file = "VOLT26"

-- annnnnd some EasterEggs
if PREFSMAN:GetPreference("EasterEggs") then
	--  41 days remain until the end of the year.
	if MonthOfYear()==10 and DayOfMonth()==20 then file = "20" end
	-- the best way to spread holiday cheer is singing loud for all to hear
	if MonthOfYear()==11 then file = "HolidayCheer" end
end

return THEME:GetPathS("", "_common menu music/" .. file)

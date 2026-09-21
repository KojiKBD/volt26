-- VOLT26 CORE: Performance/Enhanced presentation mode.
-- Loaded after SL_Init.lua, which creates the VOLT26 namespace and state.

VOLT26.Performance = {}

function VOLT26.Performance.IsEnabled()
	return VOLT26.ThemePrefs.Get("PerformanceMode") ~= false
end

function VOLT26.Performance.NeedsFirstRunChoice()
	return VOLT26.ThemePrefs.Get("PerformanceModeConfigured") ~= true
end

function VOLT26.Performance.GetInitialScreen()
	if VOLT26.Performance.NeedsFirstRunChoice() then
		return "ScreenVOLT26PerformanceSetup"
	end
	return "ScreenVOLT26Warmup"
end

function VOLT26.Performance.Choose(enhanced)
	VOLT26.ThemePrefs.Set("PerformanceMode", enhanced ~= true)
	VOLT26.ThemePrefs.Set("PerformanceModeConfigured", true)
	VOLT26.ThemePrefs.Save()
end

function VOLT26.Performance.AllowsRenderTargets()
	return not VOLT26.Performance.IsEnabled()
		and VOLT26.Compatibility.SupportsRenderToTexture()
end

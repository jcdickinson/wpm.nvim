local M = {}

local samples = { 0 }
local sample_count = 0
local sample_interval = 1
local percentile = 0.8
local timer = nil
local sparkline_chars = { "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█" }
local sparkline_factor = #sparkline_chars - 1

local function character_press()
	samples[1] = samples[1] + 1
end

local function progress()
	for i = (sample_count + 1), 2, -1 do
		samples[i] = samples[i - 1]
	end
	samples[1] = 0
end

local function make_graph(values)
	local result = ""
	local max = math.max(unpack(values))
	if max == 0 then
		max = 9000
	end
	for _, v in ipairs(values) do
		local factor = v / max
		local ci = 1 + math.floor(factor * sparkline_factor)
		result = result .. sparkline_chars[ci]
	end
	return result
end

function M.setup(options)
	options = options or {}
	sample_count = options.sample_count or 10
	sample_interval = options.sample_interval or 2000
	percentile = options.percentile or 0.8

	for _ = 1, (sample_count + 1) do
		table.insert(samples, 0)
	end

	if timer == nil then
		timer = vim.loop.new_timer()
	end

	local augroup = vim.api.nvim_create_augroup("plugin-wpm", { clear = true })
  vim.on_key(function()
    if vim.fn.mode(1) == "i" then
      character_press()
    end
  end)

	vim.api.nvim_create_autocmd("InsertEnter", {
		callback = function()
			timer:start(0, sample_interval, progress)
		end,
		group = augroup,
	})
	vim.api.nvim_create_autocmd("InsertLeave", {
		callback = function()
			timer:stop()
		end,
		group = augroup,
	})
end

function M.wpm_at_sample(index)
	local sample = samples[index] or 0
	local words = sample / 5
	local duration = sample_interval / 60000
	local words_per_minute = words / duration
	return math.floor(words_per_minute)
end

function M.samples()
	local values = {}
	for i = 1, sample_count do
		table.insert(values, M.wpm_at_sample(i))
	end
	return values
end

function M.sorted_samples()
	local values = M.samples()
	table.sort(values)
	return values
end

function M.wpm()
	local values = M.sorted_samples()
	local index = math.floor(sample_count * percentile)
	return values[index]
end

function M.sorted_graph()
	return make_graph(M.sorted_samples())
end

function M.historic_graph()
	return make_graph(M.samples())
end

return M

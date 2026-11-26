--!strict
-- Fills {name} placeholders of a text from Config/Texts. Unknown placeholders stay as they are.
return function(template: string, values: { [string]: any }): string
	return (
		string.gsub(template, "{(%w+)}", function(name: string): string?
			local value = values[name]
			return if value == nil then nil else tostring(value)
		end)
	)
end

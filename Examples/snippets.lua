local ls = require'luasnip'
-- some shorthands...
local s = ls.s
local sn = ls.sn
local t = ls.t
local i = ls.i
local f = ls.f
local c = ls.c

-- args is a table, where 1 is the text in Placeholder 1, 2 the text in
-- placeholder 2,...
local function copy(args) return args[1] end

local function jdocsnip(args)
	local nodes = {
		t({"/**"," * "}),
		i(0, {"A short Description"}),
		t({"", ""})
	}

	-- At least one param.
	if string.find(args[2][1], ", ") then
		vim.list_extend(nodes, {t({" * ", ""})})
	end


	local insert = 1
	for _, arg in ipairs(vim.split(args[2][1], ", ", true)) do
		-- Get actual name parameter.
		arg = vim.split(arg, " ", true)[2]
		if arg then
			vim.list_extend(nodes, {t({" * @param "..arg.." "}), i(insert), t({"", ""})})

			insert = insert + 1
		end
	end

	if args[1][1] ~= "void" then
		vim.list_extend(nodes, {t({" * ", " * @return "}), i(insert), t({"", ""})})
		insert = insert + 1
	end

	if vim.tbl_count(args[3]) ~= 1 then
		local exc = string.gsub(args[3][2], " throws ", "")
		vim.list_extend(nodes, {t({" * ", " * @throws "..exc.." "}), i(insert), t({"", ""})})
		insert = insert + 1
	end

	vim.list_extend(nodes, {t({" */"})})
	return sn(nil, nodes)
end

ls.snippets = {
	all = {
		-- trigger is fn.
		s("fn", {
			-- Simple static text.
			t({"//Parameters: "}),
			-- function, first parameter is the function, second the Placeholders
			-- whose text it gets as input.
			f(copy, {2}),
			t({"", "function "}),
			-- Placeholder/Insert.
			i(1),
			t({"("}),
			-- Placeholder with initial text.
			i(2, {"int foo"}),
			-- Linebreak
			t({") {", "\t"}),
			-- Last Placeholder, exit Point of the snippet. EVERY SNIPPET NEEDS Placeholder 0.
			i(0),
			t({"", "}"})
		}),
		s("class", {
			-- Choice: Switch between two different Nodes, first parameter is its position, second a list of nodes.
			c(1, {
				t({"public "}),
				t({"private "})
			}),
			t({"class "}),
			i(2),
			t({" "}),
			c(3, {
				t({"{"}),
				-- sn: Nested Snippet. Instead of a trigger, it has a position, just like insert-nodes.
				-- Inside Choices, Nodes don't need a position as the choice node is the one being jumped to.
				sn(nil, {
					t({"extends "}),
					i(0),
					t({" {"})
				}),
				sn(nil, {
					t({"implements "}),
					i(0),
					t({" {"})
				})
			}),
			t({"","\t"}),
			i(0),
			t({"", "}"})
		}),
	},
	java = {
		-- Very long example for a java class.
		s("fn", {
			d(6, jdocsnip, {2, 4, 5}), t({"", ""}),
			c(1, {
				t({"public "}),
				t({"private "})
			}),
			c(2, {
				t({"void"}),
				t({"String"}),
				t({"char"}),
				t({"int"}),
				t({"double"}),
				t({"boolean"}),
				i(nil, {""}),
			}),
			t({" "}),
			i(3, {"myFunc"}),
			t({"("}), i(4), t({")"}),
			c(5, {
				t({""}),
				sn(nil, {
					t({""," throws "}),
					i(0)
				})
			}),
			t({" {", "\t"}),
			i(0),
			t({"", "}"})
		})
	}
}

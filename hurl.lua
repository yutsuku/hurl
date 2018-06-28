module 'hurl'

local base64 = require 'base64'

hooks = {}
hooks.SendChatMessage = _G.SendChatMessage

function M.print(arg)
	DEFAULT_CHAT_FRAME:AddMessage(LIGHTYELLOW_FONT_COLOR_CODE .. '<hurl> ' .. tostring(arg), ' ')
end

function M.tokenize(str)
	local tokens = {}
	for token in string.gmatch(str, '%S+') do tinsert(tokens, token) end
	return tokens
end

function M.size(t)
	local size = 0
	for _ in pairs(t) do
		size = size + 1
	end
	return size
end

function M.escape_magic(s)
  return (s:gsub('[%^%$%(%)%%%.%[%]%*%+%-%?]','%%%1'))
end

function M.findurl(str)
	local t = {}
	for url in str:gmatch('(%w+://%S+)') do
		table.insert(t, url)
	end
	return t
end

function M.replaceurl(str)
	return '[hurl:'..base64.encode(str)..']'
end

_G.SLASH_HURL1 = '/hurl'
function SlashCmdList.HURL(command)
	if not command then return end
	local arguments = tokenize(command)
	
	if arguments[1] == 'find' and arguments[2] then
		for _,url in ipairs(findurl(command)) do
			print(url)
			print(base64.encode(url))
		end
	else
		print('hi')
	end
end


function _G.SendChatMessage(message, ...)
	if message then
		local message = message
		local f = findurl(message)
		if #f > 0 then
			for _,url in ipairs(f) do
				message = gsub(message, escape_magic(url), replaceurl(url))
			end
			return hooks.SendChatMessage(message, ...)
		end
		
	end
	
	return hooks.SendChatMessage(message, ...)
end

-- chat frame handler
local LINK_COLOR = 'ffffffff'
local ARGB_PATTERN = '%x%x%x%x%x%x%x%x'
local DIALOG_NAME = 'HURL_DIALOG'
local URL_PATTERN = '(%[hurl:%S+%])'
local clickedUrl = ''

function Hyperlink(uri, text, color)
    local link = string.format("|H%s|h[%s]|h", uri, text)

    if color then
        if not string.find(color, ARGB_PATTERN) then
            error("Invalid color value: " .. color)
        end

        link = string.format("|c%s%s|r", color, link)
    end

    return link
end

function hurl_to_str(hurl)
	hurl = string.sub(hurl, 7)
	hurl = string.sub(hurl, 1, -2)
	hurl = base64.decode(hurl)
	return hurl
end

function parseHyperlink(link)
    if string.sub(link, 1, 1) == "|" then
        return link;
    end

    return Hyperlink(link, hurl_to_str(link), LINK_COLOR)
end

function addMessage(self, text, ...)
    text = string.gsub(text, URL_PATTERN, parseHyperlink)
    hooks[self].AddMessage(self, text, ...)
end

function onHyperlinkClick()
    local uri = _G.arg1
    local link = _G.arg2

    if not string.find(uri, URL_PATTERN) then
        hooks[this].OnHyperlinkClick()
        return
    end
	
    clickedUrl = hurl_to_str(uri)
    StaticPopup_Show(DIALOG_NAME)
end

for i = 1, _G.NUM_CHAT_WINDOWS do
    local chatFrame = _G['ChatFrame' .. i]
	hooks[chatFrame] = hooks[chatFrame] or {}
    hooks[chatFrame].AddMessage = chatFrame.AddMessage
	chatFrame.AddMessage = addMessage

	hooks[chatFrame].OnHyperlinkClick = chatFrame:GetScript('OnHyperlinkClick')
	chatFrame:SetScript('OnHyperlinkClick', onHyperlinkClick)
end

_G.StaticPopupDialogs[DIALOG_NAME] = {
    text = 'Copy the URL into your clipboard (Ctrl-C):',
    button1 = _G.CLOSE,
    timeout = 0,
    whileDead = true,
    hasEditBox = true,
    hasWideEditBox = true,
    maxLetters = 500,

    OnShow = function ()
        local editBox = _G[this:GetName() .. 'WideEditBox']
        editBox:SetText(clickedUrl)
        editBox:HighlightText()

        -- Fixes editBox bleeding out of the dialog boundaries
        this:SetWidth(editBox:GetWidth() + 80)

        -- Fixes close button overlapping the edit box
        local closeButton = _G[this:GetName() .. 'Button1']
        closeButton:ClearAllPoints()
        closeButton:SetPoint('CENTER', editBox, 'CENTER', 0, -30)
    end,

    OnHide = function ()
        _G[this:GetName() .. 'WideEditBox']:SetText('')
        clickedUrl = ''
    end,

    EditBoxOnEscapePressed = function ()
        this:GetParent():Hide()
    end,

    EditBoxOnEnterPressed = function ()
        this:GetParent():Hide()
    end,
}
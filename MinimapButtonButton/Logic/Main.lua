local addonName, addon = ...;

local sort = _G.sort;
local strmatch = _G.strmatch;
local tinsert = _G.tinsert;
local executeAfter = _G.C_Timer.After;
local hooksecurefunc = _G.hooksecurefunc;
local IsAltKeyDown = _G.IsAltKeyDown;
local issecurevariable = _G.issecurevariable;

local Minimap = _G.Minimap;

local LEFTBUTTON = 'LeftButton';
local MIDDLEBUTTON = 'MiddleButton';
local ONMOUSEUP = 'OnMouseUp';

local constants = addon.constants;
local anchors = constants.anchors;

local mainFrame;
local buttonContainer;
local mainButton;
local logo;
local collectedButtonMap = {};
local collectedButtons = {};

--##############################################################################
-- minimap button collecting
--##############################################################################

local function updateLayoutOnNextFrame ()
  -- Updating layout on the next frame so SetPoint calls during that frame
  -- have passed
  executeAfter(0, addon.updateLayout);
end

local function setButtonParent (button, parent)
  if (parent ~= buttonContainer) then
    button:SetParent(buttonContainer);
  end
end

local function collectMinimapButton (button)
  -- print('collecting button:', button:GetName());

  button:SetParent(buttonContainer);
  button:SetFrameStrata(constants.FRAME_STRATA);
  button:SetScript('OnDragStart', nil);
  button:SetScript('OnDragStop', nil);

  -- Hook the function on the frame itself instead of setting a script handler
  -- to execute only when the function is called and not when the frame changes
  -- visibility because the parent gets shown/hidden
  hooksecurefunc(button, 'Show', updateLayoutOnNextFrame);
  hooksecurefunc(button, 'Hide', updateLayoutOnNextFrame);
  hooksecurefunc(button, 'SetParent', setButtonParent);

  tinsert(collectedButtons, button);
  collectedButtonMap[button] = true;
end

local function isMinimapButton (frame)
  local frameName = addon.getFrameName(frame);

  if (not frameName) then
    return false;
  end;

  if (issecurevariable(frameName)) then
    return false;
  end

  local patterns = {
    'LibDBIcon10_',
    'MinimapButton',
    'MinimapFrame',
    'MinimapIcon',
    '[-_]Minimap',
  };

  for _, pattern in ipairs(patterns) do
    if (strmatch(frameName, pattern) ~= nil) then
      return true;
    end
  end

  return false;
end

local function isButtonCollected (button)
  return (collectedButtonMap[button] ~= nil);
end

local function shouldButtonBeCollected (button)
  if (isButtonCollected(button) or addon.isButtonBlacklisted(button)) then
    return false;
  end

  return isMinimapButton(button);
end

local function scanMinimapChildren ()
  for _, child in ipairs({Minimap:GetChildren()}) do
    if (shouldButtonBeCollected(child)) then
      collectMinimapButton(child);
    end
  end
end

local function scanButtonByName (buttonName)
  local button = _G[buttonName];

  if (button ~= nil and not isButtonCollected(button)) then
    collectMinimapButton(button);
  end
end

local function collectWhitelistedButtons ()
  for buttonName in pairs(addon.options.whitelist) do
    scanButtonByName(buttonName);
  end
end

local function sortCollectedButtons ()
  sort(collectedButtons, function (a, b)
    return a:GetName() < b:GetName();
  end);
end

local function collectMinimapButtons ()
  local previousCount = #collectedButtons;

  scanMinimapChildren();
  collectWhitelistedButtons();

  if (#collectedButtons > previousCount) then
    sortCollectedButtons();
  end
end

local function collectMinimapButtonsAndUpdateLayout ()
  collectMinimapButtons();
  addon.updateLayout();
end

--##############################################################################
-- main button setup
--##############################################################################

local function toggleButtons ()
  collectMinimapButtonsAndUpdateLayout();

  if (buttonContainer:IsShown()) then
    addon.options.buttonsShown = false;
    buttonContainer:Hide();
  else
    addon.options.buttonsShown = true;
    buttonContainer:Show();
  end
end

local function setDefaultPosition ()
  mainFrame:ClearAllPoints();
  mainFrame:SetPoint(anchors.CENTER, _G.UIParent, anchors.CENTER, 0, 0);
end

local function storeMainFramePosition ()
  addon.options.position = {mainFrame:GetPoint()};
end

local function stopMovingMainFrame ()
  mainFrame:SetScript(ONMOUSEUP, nil);
  mainFrame:SetMovable(false);
  mainFrame:StopMovingOrSizing();
  storeMainFramePosition();
end

local function moveMainFrame ()
  mainButton:SetScript(ONMOUSEUP, stopMovingMainFrame);
  mainFrame:SetMovable(true);
  mainFrame:StartMoving();
end

local function initMainFrame ()
  mainFrame = _G.CreateFrame('Frame', addonName .. 'Frame');
  mainFrame:SetParent(_G.UIParent);
  mainFrame:SetFrameStrata(constants.FRAME_STRATA);
  mainFrame:SetFrameLevel(constants.FRAME_LEVEL);
  mainFrame:SetSize(1, 1);
  setDefaultPosition();
  mainFrame:SetClampedToScreen(true);
end

local function initButtonContainer ()
  buttonContainer = _G.CreateFrame('Frame', nil, _G.UIParent,
    _G.BackdropTemplateMixin and 'BackdropTemplate');
  buttonContainer:SetParent(mainFrame);
  buttonContainer:SetFrameLevel(constants.FRAME_LEVEL);
  buttonContainer:Hide();
end

local function initMainButton ()
  mainButton = _G.CreateFrame('Frame', addonName .. 'Button', _G.UIParent,
      _G.BackdropTemplateMixin and 'BackdropTemplate');
  mainButton:SetClampedToScreen(true);
  mainButton:SetParent(mainFrame);
  mainButton:SetPoint(anchors.CENTER, mainFrame, anchors.CENTER, 0, 0);
  mainButton:SetFrameLevel(constants.FRAME_LEVEL + 1);
  mainButton:Show();

  mainButton:SetScript('OnMouseDown', function (_, button)
    if (button == MIDDLEBUTTON or IsAltKeyDown()) then
      moveMainFrame();
    elseif (button == LEFTBUTTON) then
      toggleButtons();
    end
  end);
end

local function initLogo ()
  logo = mainButton:CreateTexture(nil, constants.FRAME_STRATA);
  logo:SetTexture('Interface\\AddOns\\' .. addonName ..
      '\\Media\\Logo.blp');

  logo:SetPoint(anchors.CENTER, mainButton, anchors.CENTER, 0, 0);
  logo:SetSize(constants.LOGO_SIZE, constants.LOGO_SIZE);
end

local function initFrames ()
  initMainFrame();
  initButtonContainer();
  initMainButton();
  initLogo();
end

initFrames();

--##############################################################################
-- initialization
--##############################################################################

local function applyScale ()
  mainFrame:SetScale(addon.options.scale);
end

local function restoreOptions ()
  if (addon.options.position ~= nil) then
    mainFrame:ClearAllPoints();
    mainFrame:SetPoint(unpack(addon.options.position));
  end

  applyScale();

  if (addon.options.buttonsShown == true) then
    buttonContainer:Show();
  end
end

local function init ()
  restoreOptions();
  collectMinimapButtonsAndUpdateLayout();
end

addon.registerEvent('PLAYER_LOGIN', function ()
  --[[ executing on next frame to wait for addons that create minimap buttons
       on PLAYER_LOGIN ]]
  executeAfter(0, init);

  return true;
end);

--##############################################################################
-- slash commands
--##############################################################################

addon.addSlashHandlerName('mbb');

local function printButtonLists ()
  addon.printAddonMessage('Buttons currently being collected:');

  for _, button in pairs(addon.shared.collectedButtons) do
    print(button:GetName());
  end

  if (next(addon.options.whitelist) ~= nil) then
    addon.printAddonMessage('Buttons currently being manually collected:');

    for buttonName in pairs(addon.options.whitelist) do
      print(buttonName);
    end
  end

  if (next(addon.options.blacklist) ~= nil) then
    addon.printAddonMessage('Buttons currently being ignored:');

    for buttonName in pairs(addon.options.blacklist) do
      print(buttonName);
    end
  end
end

addon.slash('list', printButtonLists);
addon.slash('default', printButtonLists);
addon.slash('reset', setDefaultPosition);

--##############################################################################
-- shared data
--##############################################################################

addon.shared = {
  mainFrame = mainFrame,
  buttonContainer = buttonContainer,
  mainButton = mainButton,
  logo = logo,
  collectedButtons = collectedButtons,
};

addon.applyScale = applyScale;
addon.collectMinimapButtonsAndUpdateLayout =
    collectMinimapButtonsAndUpdateLayout;

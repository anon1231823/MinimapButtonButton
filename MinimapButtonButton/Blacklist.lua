local _, addon = ...;

local format = _G.format;

function addon.isBlacklisted (frame)
  local frameName = addon.getFrameName(frame);

  return (frameName ~= nil and
      addon.options.blacklist[frameName] == true);
end

addon.slash('list', function ()
  addon.printAddonMessage('Buttons currently being collected:');

  for _, button in ipairs(addon.shared.collectedButtons) do
    print(button:GetName());
  end

  if (next(addon.options.blacklist) ~= nil) then
    addon.printAddonMessage('Buttons currently being ignored:');

    for buttonName in pairs(addon.options.blacklist) do
      print(buttonName);
    end
  end
end);

addon.slash('ignore', function (buttonName)
  if (_G[buttonName] == nil) then
    addon.printAddonMessage(format('No frame named "%s" was found.', buttonName));
    return;
  end

  addon.options.blacklist[buttonName] = true;
  addon.printReloadMessage(format('Button "%s" is now being ignored.', buttonName));
end);

addon.slash('unignore', function (buttonName)
  if (addon.options.blacklist[buttonName] == nil) then
    addon.printAddonMessage(format('Button "%s" is not being ignored.', buttonName));
    return;
  end

  addon.options.blacklist[buttonName] = nil;
  addon.printReloadMessage(format('Button "%s" is no longer being ignored.',
      buttonName));
end);

addon.slash('unignoreall', function ()
  if (next(addon.options.blacklist) == nil) then
    addon.printAddonMessage('No buttons are currently being ignored.');
    return;
  end

  addon.options.blacklist = {};
  addon.printReloadMessage('No more buttons are being ignored.');
end);

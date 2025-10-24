function init()
  if modules.game_interface and modules.game_interface.setupTopMenuButton then modules.game_interface.setupTopMenuButton() end
  if modules.client_options and modules.client_options.setupTopMenuButton then modules.client_options.setupTopMenuButton() end
  if modules.game_viplist and modules.game_viplist.setupTopMenuButton then modules.game_viplist.setupTopMenuButton() end
  if modules.game_skills and modules.game_skills.setupTopMenuButton then modules.game_skills.setupTopMenuButton() end
  if modules.game_questlog and modules.game_questlog.setupTopMenuButton then modules.game_questlog.setupTopMenuButton() end
  if modules.game_minimap and modules.game_minimap.setupTopMenuButton then modules.game_minimap.setupTopMenuButton() end
  if modules.game_inventory and modules.game_inventory.setupTopMenuButton then modules.game_inventory.setupTopMenuButton() end
  if modules.game_battle and modules.game_battle.setupTopMenuButton then modules.game_battle.setupTopMenuButton() end
  if modules.game_healthinfo and modules.game_healthinfo.setupTopMenuButton then modules.game_healthinfo.setupTopMenuButton() end
  if modules.game_autoloot and modules.game_autoloot.setupTopMenuButton then modules.game_autoloot.setupTopMenuButton() end
  if modules.game_conjurer and modules.game_conjurer.setupTopMenuButton then modules.game_conjurer.setupTopMenuButton() end
  -- game_store button is created directly in the mod's init()
  -- game_shop disabled - if modules.game_shop and modules.game_shop.setupTopMenuButton then modules.game_shop.setupTopMenuButton() end
end

function terminate()
end
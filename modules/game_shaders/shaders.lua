function init()
  -- add manually your shaders from /data/shaders

  -- map shaders
  g_shaders.createShader("map_default", "/shaders/map_default_vertex", "/shaders/map_default_fragment")  

  g_shaders.createShader("map_rainbow", "/shaders/map_rainbow_vertex", "/shaders/map_rainbow_fragment")
  g_shaders.addTexture("map_rainbow", "/images/shaders/rainbow.png")

  -- use modules.game_interface.gameMapPanel:setShader("map_rainbow") to set shader

  -- outfit shaders
  g_shaders.createOutfitShader("outfit_default", "/shaders/outfit_default_vertex", "/shaders/outfit_default_fragment")

  g_shaders.createOutfitShader("outfit_rainbow", "/shaders/outfit_rainbow_vertex", "/shaders/outfit_rainbow_fragment")
  g_shaders.addTexture("outfit_rainbow", "/images/shaders/rainbow.png")

  -- Elite monster shaders
  g_shaders.createOutfitShader("outfit_elite", "/shaders/outfit_elite_vertex", "/shaders/outfit_elite_fragment")
  g_shaders.addTexture("outfit_elite", "/images/shaders/gold.png")

  g_shaders.createOutfitShader("outfit_champion", "/shaders/outfit_champion_vertex", "/shaders/outfit_champion_fragment")
  g_shaders.addTexture("outfit_champion", "/images/shaders/stars.png")

  g_shaders.createOutfitShader("outfit_legendary", "/shaders/outfit_legendary_vertex", "/shaders/outfit_legendary_fragment")
  g_shaders.addTexture("outfit_legendary", "/images/shaders/brazil.png")

  -- you can use creature:setOutfitShader("outfit_rainbow") to set shader

end

function terminate()
end



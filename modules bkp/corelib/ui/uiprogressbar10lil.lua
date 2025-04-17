-- @docclass
UIProgressBar10Lil = extends(UIWidget, "UIProgressBar10Lil")

function UIProgressBar10Lil.create()
  local progressbar = UIProgressBar10Lil.internalCreate()
  progressbar:setFocusable(false)
  progressbar:setOn(true)
  progressbar.min = 0
  progressbar.max = 100
  progressbar.value = 0
  progressbar.bgBorderLeft = 0
  progressbar.bgBorderRight = 0
  progressbar.bgBorderTop = 0
  progressbar.bgBorderBottom = 0
  return progressbar
end

function UIProgressBar10Lil:setMinimum(minimum)
  self.minimum = minimum
  if self.value < minimum then
    self:setValue(minimum)
  end
end

function UIProgressBar10Lil:setMaximum(maximum)
  self.maximum = maximum
  if self.value > maximum then
    self:setValue(maximum)
  end
end

function UIProgressBar10Lil:setValue(value, minimum, maximum)
  if minimum then
    self:setMinimum(minimum)
  end

  if maximum then
    self:setMaximum(maximum)
  end

  self.value = math.max(math.min(value, self.maximum), self.minimum)
  self:updateBackground()
end

function UIProgressBar10Lil:setPercent(percent)
  self:setValue(percent, 0, 100)
end

function UIProgressBar10Lil:getPercent()
  return self.value
end

function UIProgressBar10Lil:getPercentPixels()
  return (self.maximum - self.minimum) / self:getWidth()
end

function UIProgressBar10Lil:getProgress()
  if self.minimum == self.maximum then return 1 end
  return (self.value - self.minimum) / (self.maximum - self.minimum)
end

function UIProgressBar10Lil:updateBackground()
  if self:isOn() then
    local width = math.round(math.max((self:getProgress() * (self:getWidth() - self.bgBorderLeft - self.bgBorderRight)), 1))
    local height = self:getHeight() - self.bgBorderTop - self.bgBorderBottom
    local rect = { x = self.bgBorderLeft, y = self.bgBorderTop, width = width, height = height }
    self:setImageRect(rect)
  end
end

function UIProgressBar10Lil:onSetup()
  self:updateBackground()
end

function UIProgressBar10Lil:onStyleApply(name, node)
  for name,value in pairs(node) do
    if name == 'background-border-left' then
      self.bgBorderLeft = tonumber(value)
    elseif name == 'background-border-right' then
      self.bgBorderRight = tonumber(value)
    elseif name == 'background-border-top' then
      self.bgBorderTop = tonumber(value)
    elseif name == 'background-border-bottom' then
      self.bgBorderBottom = tonumber(value)
    elseif name == 'background-border' then
      self.bgBorderLeft = tonumber(value)
      self.bgBorderRight = tonumber(value)
      self.bgBorderTop = tonumber(value)
      self.bgBorderBottom = tonumber(value)
    end
  end
end

function UIProgressBar10Lil:onGeometryChange(oldRect, newRect)
  if not self:isOn() then
    self:setHeight(0)
  end
  self:updateBackground()
end

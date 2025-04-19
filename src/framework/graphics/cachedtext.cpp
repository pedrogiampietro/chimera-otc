/*
 * Copyright (c) 2010-2017 OTClient <https://github.com/edubart/otclient>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#include "cachedtext.h"
#include "painter.h"
#include "fontmanager.h"
#include "bitmapfont.h"

CachedText::CachedText()
{
    m_font = g_fonts.getDefaultFont();
    m_align = Fw::AlignCenter;
    m_outline = false;
    m_outlineWidth = 1;
}

void CachedText::draw(const Rect& rect, const Color& color)
{
    if(!m_font)
        return;

    if(m_textMustRecache || m_textCachedScreenCoords != rect) {
        m_textMustRecache = false;
        m_textCachedScreenCoords = rect;
    }

    // Draw text outline/border using only 4 directions instead of 8 for thinner outline
    if(m_outline) {
        if (!m_textColors.empty()) {
            // Draw only in 4 directions for a thinner outline effect
            // Up
            Rect upRect = m_textCachedScreenCoords;
            upRect.moveTopLeft(m_textCachedScreenCoords.topLeft() + Point(0, -m_outlineWidth));
            m_font->drawColoredText(m_text, upRect, m_align, m_textColors);
            
            // Down
            Rect downRect = m_textCachedScreenCoords;
            downRect.moveTopLeft(m_textCachedScreenCoords.topLeft() + Point(0, m_outlineWidth));
            m_font->drawColoredText(m_text, downRect, m_align, m_textColors);
            
            // Left
            Rect leftRect = m_textCachedScreenCoords;
            leftRect.moveTopLeft(m_textCachedScreenCoords.topLeft() + Point(-m_outlineWidth, 0));
            m_font->drawColoredText(m_text, leftRect, m_align, m_textColors);
            
            // Right
            Rect rightRect = m_textCachedScreenCoords;
            rightRect.moveTopLeft(m_textCachedScreenCoords.topLeft() + Point(m_outlineWidth, 0));
            m_font->drawColoredText(m_text, rightRect, m_align, m_textColors);
        } else {
            // Draw only in 4 directions for a thinner outline effect
            // Up
            Rect upRect = m_textCachedScreenCoords;
            upRect.moveTopLeft(m_textCachedScreenCoords.topLeft() + Point(0, -m_outlineWidth));
            m_font->drawText(m_text, upRect, m_align, Color::black);
            
            // Down
            Rect downRect = m_textCachedScreenCoords;
            downRect.moveTopLeft(m_textCachedScreenCoords.topLeft() + Point(0, m_outlineWidth));
            m_font->drawText(m_text, downRect, m_align, Color::black);
            
            // Left
            Rect leftRect = m_textCachedScreenCoords;
            leftRect.moveTopLeft(m_textCachedScreenCoords.topLeft() + Point(-m_outlineWidth, 0));
            m_font->drawText(m_text, leftRect, m_align, Color::black);
            
            // Right
            Rect rightRect = m_textCachedScreenCoords;
            rightRect.moveTopLeft(m_textCachedScreenCoords.topLeft() + Point(m_outlineWidth, 0));
            m_font->drawText(m_text, rightRect, m_align, Color::black);
        }
    }

    if (m_textColors.empty()) {
        m_font->drawText(m_text, m_textCachedScreenCoords, m_align, color);
    } else {
        m_font->drawColoredText(m_text, m_textCachedScreenCoords, m_align, m_textColors);
    }
}

void CachedText::setColoredText(const std::vector<std::string>& texts)
{
    m_text = "";
    m_textColors.clear();
    for (size_t i = 0, p = 0; i < texts.size() - 1; i += 2) {
        Color c(Color::white);
        stdext::cast<Color>(texts[i + 1], c);
        m_text += texts[i];
        for (auto& c : texts[i]) {
            if ((uint8)c >= 32)
                p += 1;
        }
        m_textColors.push_back(std::make_pair(p, c));
    }
    update();
}

void CachedText::update()
{
    if(m_font)
        m_textSize = m_font->calculateTextRectSize(m_text);
    m_textMustRecache = true;
}

void CachedText::wrapText(int maxWidth)
{
    if(m_font) {
        m_text = m_font->wrapText(m_text, maxWidth, m_textColors.empty() ? nullptr : &m_textColors);
        update();
    }
}

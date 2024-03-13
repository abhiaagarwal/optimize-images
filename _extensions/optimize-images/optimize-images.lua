--[[
MIT License

Copyright (c) 2024 Abhi Agarwal

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
--]]

local imgSizes = { 1600, 800, 400 }

local function extractKeyValuePairs(input)
    local result = {}
    local skipFirst = true
    for line in input:gmatch("[^\r\n]+") do
        if skipFirst then
            skipFirst = false
        else
            local key, value = line:match("(%w+):%s(.+)")
            if key and value then
                result[key] = value
            end
        end
    end

    return result
end

local function generatePreloads(input)
    local srcset = {}

    for size, filename in pairs(input) do
        table.insert(srcset, string.format("%s %sw", filename, size))
    end

    return table.concat(srcset, ", ")
end

local function checkIfCommandExists(command)
    local checked = os.execute("command -v " .. command .. " &> /dev/null")
    return checked ~= nil
end

-- Generate image
function Image(el)
    -- this doesn't need any js; but there isn't a point with using this with epubs
    if quarto.doc.is_format("html:js") then
        local imageSrc = el.src
        quarto.log.debug("Processing image with path " .. imageSrc)
        if el.attr.classes then
            for _, value in pairs(el.attr.classes) do
                if value == "nooptimize" then
                    quarto.log.debug("Skipping image")
                    return nil
                end
            end
        end

        local hasVips = checkIfCommandExists("vips")
        if not hasVips then
            quarto.log.error("vips is not installed. Please install it to use this filter.")
            return nil
        end

        local file = io.open(imageSrc, "rb")
        if file == nil then
            quarto.log.error("Could not find image file " .. imageSrc)
            return nil
        end

        local fileContent = file:read("*all")
        file:close()
        quarto.log.debug("Loaded file")

        local imageData = extractKeyValuePairs(pandoc.pipe("vipsheader", { "-a", imageSrc }, ""))
        local height = tonumber(imageData["height"])
        if height == nil then
            quarto.log.error("Could not parse height of image")
            return nil
        end
        local width = tonumber(imageData["width"])
        if width == nil then
            quarto.log.error("Could not parse width of image")
            return nil
        end
        quarto.log.debug("Parsed height and width " .. height .. " " .. width)

        local first = nil
        local generatedImages = {}
        local filename, _ = pandoc.path.split_extension(imageSrc)
        local fmt_string = "%s-%dw.webp"
        for _, value in ipairs(imgSizes) do
            local new_filename = nil
            if value < width then
                new_filename = string.format(fmt_string, filename, value)
                generatedImages[value] = new_filename
            elseif first == nil then
                new_filename = string.format(fmt_string, filename, width)
                generatedImages[width] = new_filename
            end

            if first == nil then
                first = new_filename
            end
        end
        if first == nil then
            quarto.log.error("this shouldn't have happened. please file a bug.")
            return nil
        end

        local preloadString = generatePreloads(generatedImages)

        for width, filename in pairs(generatedImages) do
            local generatedContent = pandoc.pipe(
                "vips",
                { "thumbnail_source", "[descriptor=0]", ".webp", width, "--export-profile=srgb" },
                fileContent
            )
            local handle = io.open(filename, "w+b")
            if handle == nil then
                quarto.log.error("Could not open file " .. filename)
                return nil
            end
            handle:write(generatedContent)
        end

        html_include = '<link rel="preload" as="image" href="%s" imagesrcset="%s">'
        quarto.doc.include_text("in-header", string.format(html_include, first, preloadString))
        el.src = first
        el.attr.attributes["srcset"] = preloadString
        el.attributes.style = string.format("aspect-ratio: %d / %d", width, height)
        el.attr.attributes["decoding"] = "async"

        local version = quarto.version
        if version[1] == 1 and version[2] < 4 then
            quarto.log.warning([[
                You are on a Quarto <1.4. As a result, all the generated webp files won't be added to your output. 
                You can work around this by adding a 'resources: -"*.webp"' to your project metadata. 
                This also means the generated files will remain unmoved.
            ]])
        else
            for _, value in pairs(generatedImages) do
                quarto.doc.add_supporting(pandoc.path.join({ pandoc.path.directory(quarto.doc.input_file), value }))
            end
        end
        return el
    end
end

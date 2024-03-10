mb = require 'pandoc.mediabag'

local imgSizes = {1600, 800, 400}

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

-- Generate image
function Image(el)
    -- this doesn't need any js; but there isn't a point with using this with epubs
    if quarto.doc.is_format("html:js") then
        if el.attr.classes then
            for _, value in pairs(el.attr.classes) do
                if value == "nooptimize" then
                    quarto.log.output("skipping image")
                    return nil
                end
            end
        end
        local imageSrc = el.src
        local imageData = extractKeyValuePairs(pandoc.pipe("vipsheader", { "-a", imageSrc }, ""))
        local height = tonumber(imageData["height"])
        if height == nil then
            return nil
        end
        local width = tonumber(imageData["width"])
        if width == nil then
            return nil
        end
        local loader = imageData["loader"]
        
        local first = nil
        local generatedImages = {}
        local filename, _ = pandoc.path.split_extension(imageSrc)
        local fmt_string = "%s-%dw.webp"
        for _, value in ipairs(imgSizes) do
            local new_filename = nil
            if width > value then
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
            -- this should definitely not happen! please report a bug.
            quarto.log.error("this shouldn't have happened. please file a bug.")
            return nil
        end

        local preloadString = generatePreloads(generatedImages)

        html_include = '<link rel="preload" as="image" href="%s" imagesrcset="%s">'
        quarto.doc.include_text("in-header", string.format(html_include, first, preloadString))
        -- for key, value in pairs(generatedImages) do
        --     quarto.log.output(key, value)
        -- end
        --local vipsFile = pandoc.pipe("vips", { loader, "-" }, imageSrc)
        --quarto.log.output(imageData)
        --quarto.log.output(vipsFile)
        el.src = first
        el.attr.attributes["srcset"] = preloadString
        quarto.log.output(el)

        return el
    end
end

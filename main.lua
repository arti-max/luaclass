local ClassTranspiler = require('./luaclass') -- Импортируем наш транслятор

local Compiler = {}

-- Функция для чтения файла
function Compiler.readFile(path)
    local file = io.open(path, "r")
    if not file then
        error("Cannot open file: " .. path)
    end
    local content = file:read("*all")
    file:close()
    return content
end

-- Функция для записи файла
function Compiler.writeFile(path, content)
    local file = io.open(path, "w")
    if not file then
        error("Cannot create file: " .. path)
    end
    file:write(content)
    file:close()
end

-- Функция для проверки существования файла
function Compiler.fileExists(path)
    local file = io.open(path, "r")
    if file then
        file:close()
        return true
    end
    return false
end

-- Получение списка файлов в папке
function Compiler.getFilesInDirectory(directory, extension)
    local files = {}
    extension = extension or ".lua"
    
    -- Для Windows
    local handle = io.popen('dir "' .. directory .. '\\*' .. extension .. '" /b 2>nul')
    if handle then
        for file in handle:lines() do
            if file ~= "" then
                table.insert(files, directory .. "/" .. file)
            end
        end
        handle:close()
    end
    
    -- Если Windows команда не сработала, пробуем Unix
    if #files == 0 then
        handle = io.popen('find "' .. directory .. '" -name "*' .. extension .. '" 2>/dev/null')
        if handle then
            for file in handle:lines() do
                if file ~= "" then
                    table.insert(files, file)
                end
            end
            handle:close()
        end
    end
    
    return files
end

-- Загрузка настроек из settings.lua
function Compiler.loadSettings(settingsPath)
    settingsPath = settingsPath or "settings.lua"
    
    if not Compiler.fileExists(settingsPath) then
        -- Создаем файл настроек по умолчанию
        local defaultSettings = [[-- Конфигурация для Lua Class Compiler
return {
    -- Режим компиляции: "file", "files", "directory"
    mode = "directory",
    
    -- Для mode = "file" - один файл
    input = "src/main.lua",
    output = "dist/main.lua",
    
    -- Для mode = "files" - список файлов
    files = {
        {
            input = "src/shapes.lua",
            output = "dist/shapes.lua"
        },
        {
            input = "src/game.lua", 
            output = "dist/game.lua"
        }
    },
    
    -- Для mode = "directory" - вся папка
    inputDirectory = "src",
    outputDirectory = "dist",
    extension = ".lua",
    
    -- Общие настройки
    createDirectories = true,
    overwriteExisting = true,
    showProgress = true
}
]]
        Compiler.writeFile(settingsPath, defaultSettings)
        print("Created default settings file: " .. settingsPath)
        print("Please configure it and run again.")
        return nil
    end
    
    -- Загружаем Lua файл конфигурации
    local chunk, err = loadfile(settingsPath)
    if not chunk then
        error("Error loading settings file: " .. err)
    end
    
    local settings = chunk()
    if type(settings) ~= "table" then
        error("Settings file must return a table")
    end
    
    return settings
end

-- Создание директории
function Compiler.createDirectory(path)
    -- Заменяем слеши для Windows
    path = path:gsub("/", "\\")
    -- Пытаемся создать директорию
    os.execute('mkdir "' .. path .. '" 2>nul') -- Windows
    
    -- Для Unix систем
    path = path:gsub("\\", "/")
    os.execute('mkdir -p "' .. path .. '" 2>/dev/null') -- Unix
end

-- Получение директории из пути файла
function Compiler.getDirectory(filePath)
    return filePath:match("(.*/)")  or filePath:match("(.*\\)") or ""
end

-- Компиляция одного файла
function Compiler.compileFile(inputPath, outputPath, settings)
    if settings.showProgress then
        print("Compiling: " .. inputPath .. " -> " .. outputPath)
    end
    
    -- Проверяем существование входного файла
    if not Compiler.fileExists(inputPath) then
        print("Warning: Input file not found: " .. inputPath)
        return false
    end
    
    -- Создаем выходную директорию если нужно
    if settings.createDirectories then
        local outputDir = Compiler.getDirectory(outputPath)
        if outputDir ~= "" then
            Compiler.createDirectory(outputDir)
        end
    end
    
    -- Проверяем перезапись
    if not settings.overwriteExisting and Compiler.fileExists(outputPath) then
        print("Skipping existing file: " .. outputPath)
        return true
    end
    
    -- Читаем, компилируем и записываем
    local success, sourceCode = pcall(Compiler.readFile, inputPath)
    if not success then
        print("Error reading file: " .. inputPath)
        return false
    end
    
    local success, compiledCode = pcall(ClassTranspiler.transpile, sourceCode)
    if not success then
        print("Error transpiling file: " .. inputPath)
        print("Error: " .. compiledCode)
        return false
    end
    
    local success, err = pcall(Compiler.writeFile, outputPath, compiledCode)
    if not success then
        print("Error writing file: " .. outputPath)
        print("Error: " .. err)
        return false
    end
    
    if settings.showProgress then
        print("Successfully compiled: " .. outputPath)
    end
    
    return true
end

-- Основная функция компиляции
function Compiler.compile(settingsPath)
    local settings = Compiler.loadSettings(settingsPath)
    if not settings then
        return false
    end
    
    print("Starting compilation with mode: " .. settings.mode)
    
    if settings.mode == "file" then
        -- Компиляция одного файла
        return Compiler.compileFile(settings.input, settings.output, settings)
        
    elseif settings.mode == "files" then
        -- Компиляция списка файлов
        local success = true
        for _, fileConfig in ipairs(settings.files) do
            if not Compiler.compileFile(fileConfig.input, fileConfig.output, settings) then
                success = false
            end
        end
        return success
        
    elseif settings.mode == "directory" then
        -- Компиляция всей директории
        local files = Compiler.getFilesInDirectory(settings.inputDirectory, settings.extension)
        
        if #files == 0 then
            print("No files found in directory: " .. settings.inputDirectory)
            return false
        end
        
        local success = true
        for _, inputFile in ipairs(files) do
            -- Создаем путь для выходного файла
            local relativePath = inputFile:gsub("^" .. settings.inputDirectory:gsub("([%(%)%.%+%-%*%?%[%]%^%$%%])", "%%%1") .. "[/\\]?", "")
            local outputFile = settings.outputDirectory .. "/" .. relativePath
            
            if not Compiler.compileFile(inputFile, outputFile, settings) then
                success = false
            end
        end
        return success
        
    else
        print("Error: Unknown compilation mode: " .. settings.mode)
        return false
    end
end

-- Запуск компилятора
function Compiler.run()
    local settingsPath = arg and arg[1] or "settings.lua"
    
    print("=== Lua Class Compiler ===")
    print("Using settings: " .. settingsPath)
    
    local success = Compiler.compile(settingsPath)
    
    if success then
        print("Compilation completed successfully!")
    else
        print("Compilation failed!")
        os.exit(1)
    end
end

-- Если файл запущен напрямую
if arg and arg[0] and arg[0]:match("main%.lua$") then
    Compiler.run()
end

return Compiler

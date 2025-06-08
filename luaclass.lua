local ClassTranspiler = {}

-- Функция для замены всех new выражений в коде
function ClassTranspiler.replaceNewExpressions(code)
    -- Заменяем new ClassName(...) на ClassName:new(...)
    code = code:gsub("new%s+([A-Z][%w_]*)%s*(%b())", function(className, args)
        -- Убираем внешние скобки
        args = args:sub(2, -2)
        args = args:match("^%s*(.-)%s*$")
        
        if args == "" then
            return className .. ":new()"
        else
            return className .. ":new(" .. args .. ")"
        end
    end)
    
    return code
end

-- Функция для исправления конструкторов без аргументов
function ClassTranspiler.fixConstructorDeclaration(code)
    -- Убираем лишнюю запятую после self, если нет других аргументов
    code = code:gsub("%(self%s*,%s*%)", "(self)")
    return code
end

-- Остальные функции без изменений
function ClassTranspiler.tokenize(source)
    local tokens = {}
    local keywords = {
        ['class'] = 'CLASS',
        ['extends'] = 'EXTENDS', 
        ['constructor'] = 'CONSTRUCTOR',
        ['function'] = 'FUNCTION',
        ['end'] = 'END',
        ['super'] = 'SUPER',
        ['new'] = 'NEW',
        ['public'] = 'PUBLIC',
        ['private'] = 'PRIVATE'
    }
    
    local i = 1
    while i <= #source do
        local char = source:sub(i, i)
        
        if char:match('%s') then
            i = i + 1
        elseif char:match('%a') or char == '_' then
            local word = ""
            local start_pos = i
            while i <= #source and (source:sub(i, i):match('%w') or source:sub(i, i) == '_') do
                word = word .. source:sub(i, i)
                i = i + 1
            end
            local token_type = keywords[word] or 'IDENTIFIER'
            table.insert(tokens, {type = token_type, value = word, pos = start_pos})
        elseif char:match('%d') then
            local number = ""
            local start_pos = i
            while i <= #source and source:sub(i, i):match('%d') do
                number = number .. source:sub(i, i)
                i = i + 1
            end
            table.insert(tokens, {type = 'NUMBER', value = number, pos = start_pos})
        else
            table.insert(tokens, {type = 'SYMBOL', value = char, pos = i})
            i = i + 1
        end
    end
    
    return tokens
end

function ClassTranspiler.extractFunctionBody(source, start_pos, tokens, token_index)
    local i = token_index
    local depth = 1
    local function_start = start_pos
    local function_end = #source
    
    while i <= #tokens and depth > 0 do
        if tokens[i].type == 'FUNCTION' or tokens[i].type == 'CONSTRUCTOR' then
            depth = depth + 1
        elseif tokens[i].type == 'END' then
            depth = depth - 1
            if depth == 0 then
                function_end = tokens[i].pos + 2
            end
        end
        i = i + 1
    end
    
    return source:sub(function_start, function_end), i, function_end
end

function ClassTranspiler.parseClass(tokens, start, source)
    local class_node = {
        type = 'ClassDeclaration',
        name = tokens[start + 1].value,
        superclass = nil,
        constructor = nil,
        methods = {}
    }
    
    local i = start + 2
    
    if i <= #tokens and tokens[i].type == 'EXTENDS' then
        class_node.superclass = tokens[i + 1].value
        i = i + 2
    end
    
    while i <= #tokens and tokens[i].type ~= 'END' do
        local access_modifier = 'public'
        
        if tokens[i].type == 'PUBLIC' or tokens[i].type == 'PRIVATE' then
            access_modifier = tokens[i].value
            i = i + 1
        end
        
        if tokens[i].type == 'CONSTRUCTOR' then
            local body, next_i, end_pos = ClassTranspiler.extractFunctionBody(
                source, tokens[i].pos, tokens, i + 1
            )
            
            class_node.constructor = {
                access = access_modifier,
                body = body
            }
            i = next_i
            
        elseif tokens[i].type == 'FUNCTION' then
            local method_name = tokens[i + 1].value
            local body, next_i, end_pos = ClassTranspiler.extractFunctionBody(
                source, tokens[i].pos, tokens, i + 1
            )
            
            table.insert(class_node.methods, {
                name = method_name,
                access = access_modifier,
                body = body
            })
            i = next_i
        else
            i = i + 1
        end
    end
    
    local class_end = tokens[i] and tokens[i].pos + 2 or #source
    
    return {
        node = class_node, 
        next_index = i + 1, 
        end_pos = class_end
    }
end

-- УБИРАЕМ parseNew - теперь new обрабатывается через регулярные выражения

function ClassTranspiler.parse(source)
    local tokens = ClassTranspiler.tokenize(source)
    local ast = {type = 'Program', body = {}}
    local i = 1
    local last_pos = 1
    
    while i <= #tokens do
        if tokens[i].type == 'CLASS' then
            if tokens[i].pos > last_pos then
                local raw_code = source:sub(last_pos, tokens[i].pos - 1)
                if raw_code:match('%S') then
                    table.insert(ast.body, {type = 'RawCode', code = raw_code})
                end
            end
            
            local class_result = ClassTranspiler.parseClass(tokens, i, source)
            table.insert(ast.body, class_result.node)
            
            last_pos = class_result.end_pos + 1
            i = class_result.next_index
        else
            i = i + 1
        end
    end
    
    if last_pos <= #source then
        local raw_code = source:sub(last_pos)
        if raw_code:match('%S') then
            table.insert(ast.body, {type = 'RawCode', code = raw_code})
        end
    end
    
    return ast
end

function ClassTranspiler.generateClass(class_node)
    local lines = {}
    
    -- Создание метакласса
    table.insert(lines, string.format("-- Class %s\n", class_node.name))
    table.insert(lines, string.format("%s = {}\n", class_node.name))
    table.insert(lines, string.format("%s.__index = %s\n", class_node.name, class_node.name))
    
    -- Наследование
    if class_node.superclass then
        table.insert(lines, string.format("setmetatable(%s, {__index = %s})\n", 
                                        class_node.name, class_node.superclass))
    end
    
    -- Конструктор с обработкой new выражений
    if class_node.constructor then
        local constructor_body = class_node.constructor.body
        
        constructor_body = constructor_body:gsub("constructor%((.-)%)", 
                                               class_node.name .. ".constructor = function(self, %1)")
        
        if class_node.superclass then
            constructor_body = constructor_body:gsub("super%((.-)%)", 
                class_node.superclass .. ".constructor(self, %1)")
        end
        
        -- ИСПРАВЛЕНИЕ: убираем лишнюю запятую если нет аргументов
        constructor_body = ClassTranspiler.fixConstructorDeclaration(constructor_body)
        
        -- ИСПРАВЛЕНИЕ: обрабатываем new выражения в конструкторе
        constructor_body = ClassTranspiler.replaceNewExpressions(constructor_body)
        
        table.insert(lines, constructor_body .. "\n")
    end
    
    -- Все методы с обработкой new выражений
    for _, method in ipairs(class_node.methods) do
        local comment = method.access == 'private' and "-- private method\n" or ""
        local method_body = method.body:gsub("function%s+" .. method.name, 
                                           "function " .. class_node.name .. ":" .. method.name)
        
        -- ИСПРАВЛЕНИЕ: обрабатываем new выражения в методах
        method_body = ClassTranspiler.replaceNewExpressions(method_body)
        
        table.insert(lines, comment .. method_body .. "\n")
    end
    
    -- Метод new
    table.insert(lines, string.format("function %s:new(...)\n", class_node.name))
    table.insert(lines, "    local obj = {}\n")
    table.insert(lines, "    setmetatable(obj, self)\n")
    table.insert(lines, "    if obj.constructor then obj:constructor(...) end\n")
    table.insert(lines, "    return obj\n")
    table.insert(lines, "end\n")
    
    return table.concat(lines, '')
end

function ClassTranspiler.generateCode(ast)
    local output = {}
    
    for _, node in ipairs(ast.body) do
        if node.type == 'ClassDeclaration' then
            table.insert(output, ClassTranspiler.generateClass(node))
        elseif node.type == 'RawCode' then
            -- ИСПРАВЛЕНИЕ: применяем замену new выражений к обычному коду
            local processed_code = ClassTranspiler.replaceNewExpressions(node.code)
            table.insert(output, processed_code)
        end
    end
    
    return table.concat(output, '')
end

-- Главная функция транслятора
function ClassTranspiler.transpile(source)
    local ast = ClassTranspiler.parse(source)
    local lua_code = ClassTranspiler.generateCode(ast)
    return lua_code
end

return ClassTranspiler

# luaclass

Транслятор для добавления синтаксиса классов в Lua. Позволяет писать ООП-код с привычным синтаксисом классов, который компилируется в обычный Lua код с метатаблицами.

## Возможности

- ✅ **Классы с конструкторами** - удобное объявление классов
- ✅ **Наследование** - поддержка `extends` и `super()`
- ✅ **Модификаторы доступа** - `public` и `private` методы
- ✅ **Создание объектов** - синтаксис `new ClassName()`
- ✅ **Система сборки** - компиляция файлов и папок
- ✅ **LuaJIT совместимость** - идеально для VoxelCore

## Быстрый старт

### Установка

```bash
git clone https://github.com/arti-max/luaclass.git
cd luaclass
```

### Пример класса

**Исходный код** (`src/player.lua`):
```lua
class Player
    constructor(x, y)
        self.x = x or 0
        self.y = y or 0
        self.health = 100
    end
    
    public function move(dx, dy)
        self.x = self.x + dx
        self.y = self.y + dy
    end
    
    private function validatePosition()
        return self.x >= 0 and self.y >= 0
    end
end

class Warrior extends Player
    constructor(x, y, weapon)
        super(x, y)
        self.weapon = weapon or "sword"
        self.damage = 25
    end
    
    public function attack(target)
        if self:validatePosition() then
            target.health = target.health - self.damage
        end
    end
end

-- Создание объектов
local player = new Player(10, 20)
local warrior = new Warrior(0, 0, "axe")
```

**Скомпилированный код**:
```lua
-- Class Player
Player = {}
Player.__index = Player
Player.constructor = function(self, x, y)
    self.x = x or 0
    self.y = y or 0
    self.health = 100
end

function Player:move(dx, dy)
    self.x = self.x + dx
    self.y = self.y + dy
end

-- private method
function Player:validatePosition()
    return self.x >= 0 and self.y >= 0
end

function Player:new(...)
    local obj = {}
    setmetatable(obj, self)
    if obj.constructor then obj:constructor(...) end
    return obj
end

-- Class Warrior
Warrior = {}
Warrior.__index = Warrior
setmetatable(Warrior, {__index = Player})

Warrior.constructor = function(self, x, y, weapon)
    Player.constructor(self, x, y)
    self.weapon = weapon or "sword"
    self.damage = 25
end

function Warrior:attack(target)
    if self:validatePosition() then
        target.health = target.health - self.damage
    end
end

function Warrior:new(...)
    local obj = {}
    setmetatable(obj, self)
    if obj.constructor then obj:constructor(...) end
    return obj
end

local player = Player:new(10, 20)
local warrior = Warrior:new(0, 0, "axe")
```

## Компиляция


### Система сборки
```bash
# Первый запуск создаст settings.lua
lua main.lua

# Настройте settings.lua, затем запустите
lua main.lua
```

### Конфигурация (settings.lua)

```lua
return {
    -- Режимы: "file", "files", "directory" 
    mode = "directory",
    
    -- Для компиляции папки
    inputDirectory = "src",
    outputDirectory = "dist", 
    extension = ".lua",
    
    -- Для списка файлов
    files = {
        {input = "src/player.lua", output = "dist/player.lua"},
        {input = "src/game.lua", output = "dist/game.lua"}
    },
    
    -- Настройки
    createDirectories = true,
    overwriteExisting = true,
    showProgress = true
}
```

## Синтаксис

### Объявление класса
```lua
class ClassName
    constructor(param1, param2)
        self.param1 = param1
        self.param2 = param2
    end
end
```

### Наследование
```lua
class Child extends Parent
    constructor(param)
        super(param) -- Вызов конструктора родителя
        self.childParam = "value"
    end
end
```

### Модификаторы доступа
```lua
class Example
    public function publicMethod()
        -- Доступен всем
    end
    
    private function privateMethod()  
        -- Только документация (без защиты)
    end
end
```

### Создание объектов
```lua
local obj = new ClassName(arg1, arg2)
obj:publicMethod()
```

## Структура проекта

```
luaclass/
├── main.lua           # Основной транслятор
├── compiler.lua       # Система сборки
├── settings.lua       # Конфигурация (создается автоматически)
├── build.bat          # Скрипт сборки для Windows
└── README.md
```

## Применение

Идеально подходит для:
- **VoxelCore моды** - совместим с LuaJIT
- **Игровая разработка** - удобный ООП синтаксис
- **Большие Lua проекты** - лучшая организация кода
- **Обучение ООП** - привычный синтаксис классов

## Совместимость

- ✅ Lua 5.1+
- ✅ LuaJIT
- ✅ Windows/Linux/macOS

---

**Создано для удобного ООП в Lua без внешних зависимостей**

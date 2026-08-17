# 🚀 CastXML Portable Builder

Сборка **CastXML** из исходников с использованием готового **LLVM**, без установки CMake и Ninja в систему.

---

## 📦 Клонирование репозитория

Проект содержит **CastXML** как Git-подмодуль. Чтобы получить все файлы, выполните:

```bash
git clone --recursive https://github.com/alexwolf120/dinamika.git
```
---

## 📁 Структура папок

Перед запуском убедитесь, что папка `CastXML-Builder` имеет следующую структуру:

```plaintext
CastXML-Builder/
├── script.bat
├── CastXML/
│   └── CMakeLists.txt
├── bin/
├── lib/
│   └── llvm-12.0.1/
│       └── lib/
│           └── cmake/
│               ├── llvm/
│               │   └── LLVMConfig.cmake
│               └── clang/
│                   └── ClangConfig.cmake
└── tools/
    ├── cmake-3.20/
    │   └── bin/
    │       └── cmake.exe
    └── ninja/
        └── ninja.exe
```



## 🖥️ Требования

- **Visual Studio 2017** (Community/Professional/Enterprise) с установленными компонентами C++.
  > Скрипт автоматически загружает окружение VS 2017 через `VsDevCmd.bat`, если `cl.exe` не найден в `PATH`.
- **Windows** (x64).

---

## ▶️ Запуск сборки

Просто **дважды кликните** по `script.bat` – или запустите из командной строки:

```cmd
script.bat
```

Скрипт выполнит следующие шаги:
1. Проверит наличие компилятора MSVC; при необходимости загрузит окружение VS 2017.
2. Проверит наличие CMake, Ninja и LLVM по относительным путям.
3. Удалит старую папку сборки `CastXML-build` (если есть) и создаст новую.
4. Запустит CMake для конфигурации проекта CastXML с внешним LLVM.
5. Автоматически исправит путь к DIA SDK, если в `build.ninja` осталась ссылка на VS 2022.
6. Выполнит сборку и установку `castxml.exe` в папку `bin`.
7. Скопирует необходимые DLL из LLVM в `bin` (если они есть).

После успешного завершения в папке `bin` появится готовый к использованию `castxml.exe`.

---

## ⚙️ Настройка пути к Visual Studio

Если VS 2017 установлена не в папку по умолчанию (`C:\Program Files (x86)\Microsoft Visual Studio\2017\Community`), отредактируйте в `script.bat` строку:

```batch
call "C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\Common7\Tools\VsDevCmd.bat" -arch=x64
```

Замените `Community` на `Professional` или `Enterprise`, либо укажите полный путь к вашему `VsDevCmd.bat`.

---

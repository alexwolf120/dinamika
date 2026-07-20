#pragma once
#include <cstdint>

// Простое перечисление
enum Color
{
    RED,
    GREEN,
    BLUE
};
struct Colomnn
{
    int a;
    double b;
};
// Вложенная структура
struct Inner
{
    int x;
    double y;
    char label[16];
};

// Основная структура с разными полями
struct ComplexStruct
{
    // Базовые типы
    int id;
    float fvalue;
    double dvalue;
    char name[32];
    bool flag;

    // Вложенная структура
    Inner inner;

    // Массив
    int numbers[10];

    // Указатель (в реальном UDP так не передают, но для примера)
    // В реальности UDP передаёт только данные, указатели не имеют смысла,
    // поэтому мы опустим указатели.

    // Перечисление
    Color color;

    // Массив символов с завершающим нулём
    char message[64];
};

// Другая структура для проверки выбора по имени
struct AnotherStruct
{
    int a;
    double b;
};
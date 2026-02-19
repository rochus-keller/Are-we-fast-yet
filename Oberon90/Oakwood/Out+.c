#include <stdio.h>
#include <stdarg.h>
#include <stdio.h>
#include "Out.h"

void Out$Int(int i, short n)
{
    printf("%ld", i);
}

void Out$Real(float x, short n)
{
    printf("%f", x);
}

void Out$LongReal(double x, short n)
{ 
    printf("%f", x);
}

void Out$Ln()
{
    printf("\n");
    fflush(stdout);
}

void Out$Char(char ch)
{
    printf("%c", ch);
}

void Out$String(MIC$AP str)
{
    printf("%s", (const char*)str.$);
}

void Out$Open()
{
}



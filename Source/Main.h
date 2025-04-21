/* Copyright (c) 2002-2012 Croteam Ltd.
This program is free software; you can redistribute it and/or modify
it under the terms of version 2 of the GNU General Public License as published by
the Free Software Foundation


This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License along
with this program; if not, write to the Free Software Foundation, Inc.,
51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA. */

#ifndef SE1ECC_INCL_MAIN_H
#define SE1ECC_INCL_MAIN_H

#pragma once

// [Cecil] Moved under a separate file
#include "StringType.h"

#ifndef MAXPATHLEN
  #define MAXPATHLEN 256
#endif

// Parser methods
int yylex(void);
int yyparse(void);

// Report error during parsing
void yyerror(const char *s);

extern int _iLinesCt;
extern int _bTrackLineInformation; // This is set if #line should be inserted in tokens

extern char *_strFileNameBase;
extern char *_strFileNameBaseIdentifier;

// [Cecil] New options
extern bool _bCompatibilityMode;
extern bool _bForceExport;

// Entity component flags
#define CF_EDITOR (1UL << 1)

// [Cecil] Declare methods globally
char *stradd(const char *str1, const char *str2);
char *LineDirective(int bNewLine);

// [Cecil] Moved out of the parser file
char *RemoveLineDirective(char *str);
const char *GetLineDirective(SType &st);

// [Cecil] Special printing methods
void PrintDecl(const char *strFormat, ...);
void PrintImpl(const char *strFormat, ...);
void PrintTable(const char *strFormat, ...);
void PrintProps(const char *strFormat, ...);

// [Cecil] Check if the property list file is open
bool IsPropListOpen(void);

#endif // SE1ECC_INCL_MAIN_H

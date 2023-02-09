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

#include "StdH.h"
#include "Main.h"

int _iLinesCt = 1;
int _bTrackLineInformation = 0; // This is set if #line should be inserted in tokens

FILE *_fImplementation;
FILE *_fDeclaration;
FILE *_fTables;
char *_strFileNameBase;
char *_strFileNameBaseIdentifier;

// [Cecil] Generate sources compatibile with vanilla
bool _bCompatibilityMode = false;

// [Cecil] Export class from the library without specifying it in code
bool _bForceExport = false;

extern "C" int yywrap(void) {
  return 1;
};

extern FILE *yyin;

// Local variables
static char _strInputFileName[MAXPATHLEN] = {0};
static bool _bError = false;

static bool _bRemoveLineDirective = false;

// String concatenation
SType SType::operator+(const SType &other) const {
  SType sum;
  sum.strString = stradd(strString, other.strString);
  sum.bCrossesStates = (bCrossesStates | other.bCrossesStates);
  sum.iLine = -1;
  return sum;
};

// Concatenate two strings together
char *stradd(const char *str1, const char *str2) {
  char *strResult;
  strResult = (char *)malloc(strlen(str1) + strlen(str2) + 1);

  strcpy(strResult, str1);
  strcat(strResult, str2);
  return strResult;
};

// [Cecil] Replaced index with a flag for starting with a line break
char *LineDirective(int bNewLine) {
  static char str[256];

  // [Cecil] No line directives
  if (_bRemoveLineDirective) {
    str[0] = '\0';
    return str;
  }

  // [Cecil] Use line counter instead of an index and surround the filename with quotes
  sprintf(str, "%s#line %d \"%s\"\n", (bNewLine ? "\n" : ""), _iLinesCt, _strInputFileName);

  // [Cecil] Return pointer to the static array to not waste memory
  return str;
};

// [Cecil] Moved out of the parser file
char *RemoveLineDirective(char *str) {
  if (str[0] == '\n' && str[1] == '#') {
    return strchr(str + 2, '\n') + 1;
  }

  return str;
};

// [Cecil] Moved out of the parser file
char *GetLineDirective(SType &st) {
  char *str = st.strString;

  if (str[0] == '\n' && str[1] == '#' && str[2] == 'l') {
    char *strResult = strdup(str);
    strchr(strResult + 3, '\n')[1] = '\0';

    return strResult;
  }

  return "";
};

// [Cecil] Special printing methods
void PrintDecl(const char *strFormat, ...) {
  va_list arg;
  va_start(arg, strFormat);
  vfprintf(_fDeclaration, strFormat, arg);
  va_end(arg);
};

void PrintImpl(const char *strFormat, ...) {
  va_list arg;
  va_start(arg, strFormat);
  vfprintf(_fImplementation, strFormat, arg);
  va_end(arg);
};

void PrintTable(const char *strFormat, ...) {
  va_list arg;
  va_start(arg, strFormat);
  vfprintf(_fTables, strFormat, arg);
  va_end(arg);
};

// Report error during parsing
void yyerror(char *s) {
  fprintf(stderr, "%s(%d): Error: %s\n", _strInputFileName, _iLinesCt, s);
  _bError = true;
};

// Change extension of the filename
static char *ChangeExt(const char *strFileName, const char *strNewExtension) {
  int iLength = strlen(strFileName) + strlen(strNewExtension) + 1;

  // Copy filename into the new string with enough characters
  char *strChanged = (char *)malloc(iLength + 1);
  strcpy(strChanged, strFileName);

  // Find filename separator from the end
  char *pchDot = strrchr(strChanged, '.');

  // Set it to the end of the filename, if none found
  if (pchDot == NULL) {
    pchDot = strChanged + iLength;
  }

  // Append extension to the filename
  strcpy(pchDot, strNewExtension);
  return strChanged;
};

// Open a file and report error upon failure
static FILE *OpenFile(const char *strFileName, const char *strMode) {
  // Open the input file
  FILE *f = fopen(strFileName, strMode);

  // Report error if couldn't open
  if (f == NULL) {
    fprintf(stderr, "Can't open file '%s': %s\n", strFileName, strerror(errno));
    exit(EXIT_FAILURE);
  }

  return f;
};

// Print an ECC header to a file
static void PrintHeader(FILE *f) {
  // [Cecil] One string is enough
  fprintf(f, "// This file is generated by Entity Class Compiler, (c) 2002-2012 Croteam Ltd.\n\n");
};

// [Cecil] Replace specific characters in a string with another character
static void ReplaceChar(char *str, char chOld, char chNew) {
  // Go until the end
  while (*str != '\0')
  {
    if (*str == chOld) {
      *str = chNew;
    }
    ++str;
  }
};

// Replace contents of an old file with new ones
static inline void ReplaceFile(const char *strOldFile, const char *strNewFile) {
  remove(strOldFile);
  rename(strNewFile, strOldFile);
};

// Replace contents of an old file with new ones if they are different
// Used to keep headers from constantly updating upon changing the implementation
static void ReplaceIfChanged(const char *strOldFile, const char *strNewFile) {
  int iChanged = 1;
  FILE *fOld = fopen(strOldFile, "r");

  if (fOld != NULL) {
    iChanged = 0;
    FILE *fNew = OpenFile(strNewFile, "r");

    while (!feof(fOld)) {
      char strOldLine[4096] = "#l";
      char strNewLine[4096] = "#l";

      // Skip line directives in both files
      while (strNewLine[0] == '#' && strNewLine[1] == 'l' && !feof(fNew)) {
        fgets(strNewLine, sizeof(strNewLine) - 1, fNew);
      }

      while (strOldLine[0] == '#' && strOldLine[1] == 'l' && !feof(fOld)) {
        fgets(strOldLine, sizeof(strOldLine) - 1, fOld);
      }

      // Found a line that differs
      if (strcmp(strNewLine, strOldLine) != 0) {
        iChanged = 1;
        break;
      }
    }

    fclose(fNew);
    fclose(fOld);
  }

  // If there are changes
  if (iChanged) {
    // Replace the file
    ReplaceFile(strOldFile, strNewFile);

  } else {
    // Otherwise discard the new file
    remove(strNewFile);
  }
};

// Entry point
int main(int argc, char *argv[]) {
  // Print usage if not enough arguments
  if (argc < 2) {
    printf("Usage: Ecc <es_file_name>\n       -line\n");
    return EXIT_FAILURE;
  }

  // Parse extra arguments after the filename
  for (int iExtra = 2; iExtra < argc; iExtra++) {
    // Remove line directives
    if (strncmp(argv[iExtra], "-line", 5) == 0) {
      _bRemoveLineDirective = true;

    } else if (strncmp(argv[iExtra], "-compat", 7) == 0) {
      _bCompatibilityMode = true;

    } else if (strncmp(argv[iExtra], "-export", 7) == 0) {
      _bForceExport = true;
    }
  }

  // Open input file and make lex use it
  const char *strFileName = argv[1];
  yyin = OpenFile(strFileName, "r");

  char *strImplTmp = ChangeExt(strFileName, ".cpp_tmp");
  char *strImplOld = ChangeExt(strFileName, ".cpp");
  char *strDeclTmp = ChangeExt(strFileName, ".h_tmp");
  char *strDeclOld = ChangeExt(strFileName, ".h");
  char *strTablTmp = ChangeExt(strFileName, "_tables.h_tmp");
  char *strTablOld = ChangeExt(strFileName, "_tables.h");

  // Open temporary output files
  _fImplementation = OpenFile(strImplTmp, "w");
  _fDeclaration    = OpenFile(strDeclTmp, "w");
  _fTables         = OpenFile(strTablTmp, "w");

  // Get filename as a preprocessor-usable identifier
  _strFileNameBase = ChangeExt(strFileName, "");
  _strFileNameBaseIdentifier = strdup(_strFileNameBase);

  // [Cecil] Replace all non-alphanumeric characters
  {
    char *strFile = _strFileNameBaseIdentifier;

    while (*strFile != '\0') {
      char &ch = *strFile;

      if (ch != '_' && !isalnum(ch)) {
        ch = '_';
      }

      ++strFile;
    }
  }

  // Print file headers
  PrintHeader(_fImplementation);
  PrintHeader(_fDeclaration);
  PrintHeader(_fTables);

  // Remember input filename
  _fullpath(_strInputFileName, strFileName, MAXPATHLEN);

  ReplaceChar(_strInputFileName, '\\', '/');

  // Parse input file and generate the output files
  yyparse();

  // Close all files
  fclose(_fImplementation);
  fclose(_fDeclaration);
  fclose(_fTables);

  // If there were no errors
  if (!_bError) {
    // Update files that have changed
    ReplaceFile(strImplOld, strImplTmp);
    ReplaceIfChanged(strDeclOld, strDeclTmp);
    ReplaceIfChanged(strTablOld, strTablTmp);

    return EXIT_SUCCESS;
  }

  // Otherwise delete all files
  remove(strImplTmp);
  remove(strDeclTmp);
  remove(strTablTmp);

  return EXIT_FAILURE;
};

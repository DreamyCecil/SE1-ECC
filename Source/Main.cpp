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

static FILE *_fImplementation;
static FILE *_fDeclaration;
static FILE *_fTables;
static FILE *_fProps; // [Cecil] Property lists for all classes
char *_strFileNameBase;
char *_strFileNameBaseIdentifier;

// [Cecil] Generate sources compatibile with vanilla
bool _bCompatibilityMode = false;

// [Cecil] Export class from the library without specifying it in code
bool _bForceExport = false;

// [Cecil] Output file for the list of property references
static char *_strPropListFile = "";

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
const char *GetLineDirective(SType &st) {
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

void PrintProps(const char *strFormat, ...) {
  va_list arg;
  va_start(arg, strFormat);
  vfprintf(_fProps, strFormat, arg);
  va_end(arg);
};

// [Cecil] Check if the property list file is open
bool IsPropListOpen(void) {
  return strcmp(_strPropListFile, "") != 0;
};

// Report error during parsing
void yyerror(const char *s) {
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

// [Cecil] Change filename under the same directory
static char *ChangeFileName(const char *strFullPath, const char *strNewFileName) {
  int iLength = strlen(strFullPath) + strlen(strNewFileName) + 1;

  // Copy filename into the new string with enough characters
  char *strChanged = (char *)malloc(iLength + 1);
  strcpy(strChanged, strFullPath);

  // Find directory separator from the end
  char *pchDir = strrchr(strChanged, '\\');
  if (pchDir == NULL) pchDir = strrchr(strChanged, '/');

  // Set it to the beginning, if none found
  if (pchDir == NULL) {
    pchDir = strChanged;

  // Skip the character itself
  } else {
    pchDir++;
  }

  // Append new filename
  strcpy(pchDir, strNewFileName);
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
    printf("Usage: Ecc <es_file_name>\n"
      "  -line : Compile without #line preprocessor directives pointing to places in the .es file\n"
      "  -compat : Make compiled code compatible with vanilla Serious Sam SDK\n"
      "  -export : Export entity class regardless of the 'export' keyword after 'class'\n"
      "  -proplist <file> : Generate an inline file that defines a list of property references by variable name\n"
      "    If the file already exists, a list of this entity will be appended at the end of it\n"
      "    If the filename is '*', it defaults to '_DefinePropertyRefLists.inl' in the same directory as the .es file\n"
    );
    return EXIT_FAILURE;
  }

  // Remember input filename
  const char *strFileName = argv[1];
  _fullpath(_strInputFileName, strFileName, MAXPATHLEN);

  ReplaceChar(_strInputFileName, '\\', '/');

  // Parse extra arguments after the filename
  for (int iExtra = 2; iExtra < argc; iExtra++) {
    // Remove line directives
    if (strncmp(argv[iExtra], "-line", 5) == 0) {
      _bRemoveLineDirective = true;

    } else if (strncmp(argv[iExtra], "-compat", 7) == 0) {
      _bCompatibilityMode = true;

    } else if (strncmp(argv[iExtra], "-export", 7) == 0) {
      _bForceExport = true;

    } else if (strncmp(argv[iExtra], "-proplist", 9) == 0) {
      // Try to get the filename
      if (iExtra == argc - 1) {
        fprintf(stderr, "%s: Warning: No output file specified after the '-proplist' argument\n", _strInputFileName);
        break;
      }

      iExtra++;
      _strPropListFile = argv[iExtra];
    }
  }

  // Open input file and make lex use it
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

  // [Cecil] Open property lists
  int iPropsOpen = 0;

  if (IsPropListOpen()) {
    char *strFile = _strPropListFile;

    // Use default filename in the same directory
    if (strcmp(_strPropListFile, "*") == 0) {
      strFile = ChangeFileName(strFileName, "_DefinePropertyRefLists.inl");
    }

    // Check if the file already exists
    _fProps = fopen(strFile, "r");

    // Reopen to append at the end
    if (_fProps != NULL) {
      _fProps = freopen(strFile, "a", _fProps);

      // Shouldn't happen
      if (_fProps == NULL) {
        fprintf(stderr, "Can't open file '%s' for appending: %s\n", strFile, strerror(errno));
        return EXIT_FAILURE;
      }

      iPropsOpen = 1;

    // Create a new file
    } else {
      _fProps = OpenFile(strFile, "w");
      iPropsOpen = 2;
    }
  }

  // Get filename as a preprocessor-usable identifier
  _strFileNameBase = ChangeExt(strFileName, "");
  ReplaceChar(_strFileNameBase, '\\', '/'); // [Cecil] Convert path slashes for includes

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

  // [Cecil] Add necessary stuff at the beginning of property lists
  if (iPropsOpen == 2) {
    PrintHeader(_fProps);

    PrintProps("\n"
      "// [Cecil] NOTE: This inline code can be included in any place that needs to retrieve properties of linked vanilla entities\n"
      "// by variable name. It can be used in any project that utilizes this SDK. However, before including it, make sure to include\n"
      "// <EngineEx/PropertyTables.h> header that this code relies on.\n\n"

      "// Example: You can create a method that fills a CPropertyRefTable structure from an argument with all of the property tables\n"
      "// by defining your own ENTITYPROPERTYREF_ENTRY macro as such:\n"
      "//   #define ENTITYPROPERTYREF_ENTRY(Class, Refs, RefsCount) map.FillPropertyReferences(#Class, Refs, RefsCount)\n\n\n"

      "#include <EccExtras/EntityProperties.h>\n\n"
    );

    PrintProps(
      "// Please specify your own code for this macro\n"
      "#ifndef ENTITYPROPERTYREF_ENTRY\n"
      "  #define ENTITYPROPERTYREF_ENTRY(Class, Refs, RefsCount)\n"
      "#endif\n\n"

      "// You can provide your own declaration specifiers using this macro\n"
      "#ifndef ENTITYPROPERTYREF_DECL\n"
      "  #define ENTITYPROPERTYREF_DECL static\n"
      "#endif\n"
    );
  }

  // Parse input file and generate the output files
  yyparse();

  // Close all files
  fclose(_fImplementation);
  fclose(_fDeclaration);
  fclose(_fTables);

  // [Cecil]
  if (iPropsOpen != 0) {
    fclose(_fProps);
  }

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

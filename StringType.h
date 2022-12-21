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

#pragma once

// String type for the parser
struct SType {
  char *strString;
  int bCrossesStates;
  int iLine;

  // Default constructor
  SType(void) {
    Set("");
  };

  // Constructor from a string
  SType(const char *str) {
    Set(str);
  };

  // Copy constructor
  SType(const SType &other) {
    Copy(other);
  };

  // Assignment from a string
  const SType &operator=(char *str) {
    Set(str);
    return *this;
  };

  // Assignment from another class
  const SType &operator=(const SType &other) {
    Copy(other);
    return *this;
  };

  // String concatenation
  SType operator+(const SType &other) const;

  // [Cecil] Set a string
  inline void Set(const char *str) {
    strString = strdup(str);
    bCrossesStates = 0;
    iLine = -1;
  };

  // [Cecil] Copy from another class
  inline void Copy(const SType &other) {
    strString = strdup(other.strString);
    bCrossesStates = other.bCrossesStates;
    iLine = other.iLine;
  };
};

#define YYSTYPE SType

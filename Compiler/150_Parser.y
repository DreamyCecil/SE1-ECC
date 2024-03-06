%{
#include "StdH.h"

static char *_strCurrentClass;
static int _iCurrentClassID;
static char *_strCurrentBase;
static char *_strCurrentDescription;
static char *_strCurrentThumbnail;
static char *_strCurrentEnum;
static int _bClassIsExported = 0;

static char *_strCurrentPropertyID;         
static char *_strCurrentPropertyIdentifier; 
static char *_strCurrentPropertyPropertyType;
static char *_strCurrentPropertyEnumType;   
static char *_strCurrentPropertyDataType;
static char *_strCurrentPropertyName;       
static char *_strCurrentPropertyShortcut;
static char *_strCurrentPropertyColor;
static char *_strCurrentPropertyFlags;
static char *_strCurrentPropertyDefaultCode;

static char *_strCurrentEventList;
static char *_strCurrentEventCheck;

static char *_strCurrentComponentIdentifier;
static char *_strCurrentComponentType;
static char *_strCurrentComponentID;     
static char *_strCurrentComponentFileName;
static unsigned long _ulCurrentComponentFlags = 0;

static int _ctInProcedureHandler = 0;
static char _strLastProcedureName[256];

static char _strInWaitName[256];
static char _strAfterWaitName[256];
static char _strInWaitID[256];
static char _strAfterWaitID[256];

static char _strInLoopName[256];
static char _strAfterLoopName[256];
static char _strInLoopID[256];
static char _strAfterLoopID[256];
static char _strCurrentStateID[256];

static int _bInProcedure;   // set if currently compiling a procedure
static int _bInHandler;
static int _bHasOtherwise;  // set if current 'wait' block has an 'otherwise' statement

static char *_strCurrentEvent;
static int _bFeature_AbstractBaseClass;
static int _bFeature_ImplementsOnInitClass;
static int _bFeature_ImplementsOnEndClass;
static int _bFeature_ImplementsOnPrecache;
static int _bFeature_ImplementsOnWorldInit;
static int _bFeature_ImplementsOnWorldEnd;
static int _bFeature_ImplementsOnWorldTick;
static int _bFeature_ImplementsOnWorldRender;
static int _bFeature_CanBePredictable;

static int _iNextFreeID;
inline int CreateID(void) {
  return _iNextFreeID++;
}

static int _ctBraces = 0;
void OpenBrace(void) {
  _ctBraces++;
}
void CloseBrace(void) {
  _ctBraces--;
}
SType Braces(int iBraces) {
  static char strBraces[50];
  memset(strBraces, '}', sizeof(strBraces));
  strBraces[iBraces] = 0;
  return SType(strBraces);
}
void AddHandlerFunction(char *strProcedureName, int iStateID)
{
  PrintDecl("  BOOL %s(const CEntityEvent &__eeInput);\n", strProcedureName);
  PrintTable(" {0x%08x, -1, CEntity::pEventHandler(&%s::%s), "
    "DEBUGSTRING(\"%s::%s\")},\n",
    iStateID, _strCurrentClass, strProcedureName, _strCurrentClass, strProcedureName);
}


void AddHandlerFunction(char *strProcedureName, char *strStateID, char *strBaseStateID)
{
  PrintDecl("  BOOL %s(const CEntityEvent &__eeInput);\n", strProcedureName);
  PrintTable(" {%s, %s, CEntity::pEventHandler(&%s::%s),"
    "DEBUGSTRING(\"%s::%s\")},\n",
    strStateID, strBaseStateID, _strCurrentClass, strProcedureName,
    _strCurrentClass, RemoveLineDirective(strProcedureName));
  strcpy(_strLastProcedureName, RemoveLineDirective(strProcedureName));
  _ctInProcedureHandler = 0;
}

void CreateInternalHandlerFunction(char *strFunctionName, char *strID)
{
  int iID = CreateID();
  _ctInProcedureHandler++;
  sprintf(strID, "0x%08x", iID);
  sprintf(strFunctionName, "H0x%08x_%s_%02d", iID, _strLastProcedureName, _ctInProcedureHandler);
  AddHandlerFunction(strFunctionName, iID);
}

void DeclareFeatureProperties(void)
{
  if (_bFeature_CanBePredictable) {
    PrintTable(" CEntityProperty(CEntityProperty::EPT_ENTITYPTR, NULL, (0x%08x<<8)+%s, offsetof(%s, %s), %s, %s, %s, %s),\n",
      _iCurrentClassID,
      "255",
      _strCurrentClass,
      "m_penPrediction",
      "\"\"",
      "0",
      "0",
      "0");
    PrintDecl("  %s %s;\n",
      "CEntityPointer",
      "m_penPrediction"
      );
    PrintImpl("  m_penPrediction = NULL;\n");
  }
}

#undef YYERROR_VERBOSE

%}

/* BISON Declarations */

/* different type of constants */
%token c_char
%token c_int
%token c_float
%token c_bool
%token c_string

/* the standard cpp identifier */
%token identifier

/* specially bracketed cpp blocks */
%token cppblock

/* standard cpp-keywords */
%token k_while
%token k_for
%token k_if
%token k_else
%token k_enum
%token k_switch
%token k_case
%token k_class
%token k_do
%token k_void
%token k_const
%token k_inline
%token k_static
%token k_virtual
%token k_return
%token k_autowait
%token k_autocall
%token k_waitevent

/* aditional keywords */
%token k_event
%token k_name
%token k_thumbnail
%token k_features
%token k_uses
%token k_export

%token k_texture
%token k_sound
%token k_model
%token k_skamodel
%token k_editor

%token k_properties
%token k_components
%token k_functions
%token k_procedures

%token k_wait
%token k_on
%token k_otherwise

%token k_call
%token k_jump
%token k_stop
%token k_resume
%token k_pass

/* special data types */
%token k_CTString
%token k_CTStringTrans
%token k_CTFileName
%token k_CTFileNameNoDep
%token k_BOOL
%token k_COLOR
%token k_FLOAT
%token k_INDEX
%token k_TIME
%token k_RANGE
%token k_CEntityPointer
%token k_CModelObject
%token k_CModelInstance
%token k_CAnimObject
%token k_CSoundObject
%token k_CPlacement3D
%token k_FLOATaabbox3D
%token k_FLOATmatrix3D
%token k_FLOATquat3D
%token k_ANGLE
%token k_FLOAT3D
%token k_ANGLE3D
%token k_FLOATplane3D
%token k_ANIMATION
%token k_ILLUMINATIONTYPE
%token k_FLAGS

%start program

%%

/*/////////////////////////////////////////////////////////
 * Global structure of the source file.
 */
program 
  : /* empty file */ {}
  | c_int {
    int iID = atoi($1.strString);
    if(iID>32767) {
      yyerror("Maximum allowed id for entity source file is 32767");
    }
    _iCurrentClassID = iID;
    _iNextFreeID = iID<<16;
    PrintDecl("#ifndef _%s_INCLUDED\n", _strFileNameBaseIdentifier);
    PrintDecl("#define _%s_INCLUDED 1\n", _strFileNameBaseIdentifier);

  } opt_global_cppblock {

    //PrintImpl("\n#undef DECL_DLL\n#define DECL_DLL _declspec(dllimport)\n");
  } uses_list {
    //PrintImpl("\n#undef DECL_DLL\n#define DECL_DLL _declspec(dllexport)\n");

    PrintImpl("#include <%s.h>\n", _strFileNameBase);
    PrintImpl("#include <%s_tables.h>\n", _strFileNameBase);
    _strCurrentEventList = strdup("");
  } enum_and_event_declarations_list {
  } opt_global_cppblock {
  } opt_class_declaration {
    PrintDecl("#endif // _%s_INCLUDED\n", _strFileNameBaseIdentifier);
  }
  ;


/*
 * Prolog cpp code.
 */
opt_global_cppblock
  : /* null */
  | cppblock { PrintImpl("%s\n", $1.strString); }
  ;

uses_list
  : /* null */
  | uses_list uses_statement
  ;
uses_statement
  : k_uses c_string ';' {
    char *strUsedFileName = strdup($2.strString);
    strUsedFileName[strlen(strUsedFileName)-1] = 0;
    /* [Cecil] Quotes instead of angle-brackets to allow more freedom */
    PrintDecl("#include \"%s.h\"\n", strUsedFileName+1);
  }
  ;


enum_and_event_declarations_list
  : /* null */
  | enum_and_event_declarations_list enum_declaration
  | enum_and_event_declarations_list event_declaration
  ;
/*/////////////////////////////////////////////////////////
 * Enum types declarations
 */
enum_declaration
  : k_enum identifier { 
    _strCurrentEnum = $2.strString;
    PrintTable("EP_ENUMBEG(%s)\n", _strCurrentEnum );
    PrintDecl("extern DECL_DLL CEntityPropertyEnumType %s_enum;\n", _strCurrentEnum );
    PrintDecl("enum %s {\n", _strCurrentEnum );
  } '{' enum_values_list opt_comma '}' ';' {
    PrintTable("EP_ENUMEND(%s);\n\n", _strCurrentEnum);
    PrintDecl("};\n");
    PrintDecl("DECL_DLL inline void ClearToDefault(%s &e) { e = (%s)0; } ;\n", _strCurrentEnum, _strCurrentEnum);
  }
  ;
opt_comma : /*null*/ | ',';
enum_values_list
  : enum_value
  | enum_values_list ',' enum_value
  ;

enum_value
  : c_int identifier c_string {
    PrintTable("  EP_ENUMVALUE(%s, %s),\n", $2.strString, $3.strString);
    PrintDecl("  %s = %s,\n", $2.strString, $1.strString);
  }
  ;

/*/////////////////////////////////////////////////////////
 * Event declarations
 */
event_declaration
  : k_event identifier { 
    _strCurrentEvent = $2.strString;
    int iID = CreateID();
    PrintDecl("#define EVENTCODE_%s 0x%08x\n", _strCurrentEvent, iID);
    PrintDecl("class DECL_DLL %s : public CEntityEvent {\npublic:\n",
      _strCurrentEvent);
    PrintDecl("%s();\n", _strCurrentEvent );
    PrintDecl("CEntityEvent *MakeCopy(void);\n");
    PrintDecl("BOOL CheckIDs(void);\n");
    PrintImpl(
      "CEntityEvent *%s::MakeCopy(void) { "
      "CEntityEvent *peeCopy = new %s(*this); "
      "return peeCopy;}\n",
      _strCurrentEvent, _strCurrentEvent);
    PrintDecl("  SLONG GetSizeOf(void);\n");
    PrintImpl(
      "SLONG %s::GetSizeOf(void) { "
      "  return sizeof(*this);}\n",
      _strCurrentEvent);

    PrintImpl("%s::%s() : CEntityEvent(EVENTCODE_%s) {\n",
      _strCurrentEvent, _strCurrentEvent, _strCurrentEvent);

    PrintTable("CEntityEvent *%s_New(void) { return new %s; };\n", _strCurrentEvent, _strCurrentEvent);
    PrintTable(
      "CDLLEntityEvent DLLEvent_%s = {\n"
      "  0x%08x, &%s_New\n"
      "};\n",
      _strCurrentEvent, iID, _strCurrentEvent);

    char strBuffer[256];
    sprintf(strBuffer, "  &DLLEvent_%s,\n", _strCurrentEvent);
    _strCurrentEventList = stradd(strBuffer, _strCurrentEventList);
    _strCurrentEventCheck = strdup("");

  } '{' event_members_list opt_comma '}' ';' {
    PrintImpl("};\n");
    PrintDecl("};\n");
    PrintDecl("DECL_DLL inline void ClearToDefault(%s &e) { e = %s(); } ;\n", _strCurrentEvent, _strCurrentEvent);

    PrintImpl("BOOL %s::CheckIDs(void) {\treturn TRUE %s; }\n\n", _strCurrentEvent, _strCurrentEventCheck);
  }
  ;

event_members_list
  : /* null */
  | non_empty_event_members_list
  ;

non_empty_event_members_list
  : event_member
  | event_members_list ',' event_member
  ;

event_member
  : any_type identifier {
    PrintDecl("%s %s;\n", $1.strString, $2.strString);
    PrintImpl(" ClearToDefault(%s);\n", $2.strString);
    if (strcmp($1.strString, "CEntityID")==0) {
      char strBuffer[256];
      sprintf(strBuffer, "&& %s.IsValid()", $2.strString);
      _strCurrentEventCheck = stradd(_strCurrentEventCheck, strBuffer);
    }
  }
  ;

/*/////////////////////////////////////////////////////////
 * The class declaration structure.
 */
opt_class_declaration 
  : /* null */
  | class_declaration
  ;

class_declaration 
  : /* null */
  | class_optexport identifier ':' identifier '{' 
  k_name c_string ';'
  k_thumbnail c_string ';' {
    _strCurrentClass = $2.strString;
    _strCurrentBase = $4.strString;
    _strCurrentDescription = $7.strString;
    _strCurrentThumbnail = $10.strString;

    if (strlen(_strCurrentEventList)>0) {
      PrintTable("CDLLEntityEvent *%s_events[] = {\n%s};\n", _strCurrentClass, _strCurrentEventList);
      PrintTable("#define %s_eventsct ARRAYCOUNT(%s_events)\n", _strCurrentClass, _strCurrentClass);
    } else {
      PrintTable("CDLLEntityEvent *%s_events[] = {NULL};\n", _strCurrentClass);
      PrintTable("#define %s_eventsct 0\n", _strCurrentClass);
    }

    PrintTable("#define ENTITYCLASS %s\n\n", _strCurrentClass);
    PrintDecl("extern \"C\" DECL_DLL CDLLEntityClass %s_DLLClass;\n",
      _strCurrentClass);
    PrintDecl("%s %s : public %s {\npublic:\n",
      $1.strString, _strCurrentClass, _strCurrentBase);

  } opt_features {
    PrintDecl("  %s virtual void SetDefaultProperties(void);\n", _bClassIsExported?"":"DECL_DLL");
    PrintImpl("void %s::SetDefaultProperties(void) {\n", _strCurrentClass);
    PrintTable("CEntityProperty %s_properties[] = {\n", _strCurrentClass);

  } k_properties ':' property_declaration_list {
    PrintImpl("  %s::SetDefaultProperties();\n}\n", _strCurrentBase);

    PrintTable("CEntityComponent %s_components[] = {\n", _strCurrentClass);
  } opt_internal_properties {
  } k_components ':' component_declaration_list {
    _bTrackLineInformation = 1;
    PrintTable("CEventHandlerEntry %s_handlers[] = {\n", _strCurrentClass);

    _bInProcedure = 0;
    _bInHandler = 0;
  } k_functions ':' function_list {

    _bInProcedure = 1;
  } k_procedures ':' procedure_list {
  } '}' ';' {
    PrintTable("};\n#define %s_handlersct ARRAYCOUNT(%s_handlers)\n", 
      _strCurrentClass, _strCurrentClass);
    PrintTable("\n");

    if (_bFeature_AbstractBaseClass) {
      PrintTable("CEntity *%s_New(void) { return NULL; };\n",
        _strCurrentClass);
    } else {
      PrintTable("CEntity *%s_New(void) { return new %s; };\n",
        _strCurrentClass, _strCurrentClass);
    }

    if (!_bFeature_ImplementsOnInitClass) {
      PrintTable("void %s_OnInitClass(void) {};\n", _strCurrentClass);
    } else {
      PrintTable("void %s_OnInitClass(void);\n", _strCurrentClass);
    }

    if (!_bFeature_ImplementsOnEndClass) {
      PrintTable("void %s_OnEndClass(void) {};\n", _strCurrentClass);
    } else {
      PrintTable("void %s_OnEndClass(void);\n", _strCurrentClass);
    }

    if (!_bFeature_ImplementsOnPrecache) {
      PrintTable("void %s_OnPrecache(CDLLEntityClass *pdec, INDEX iUser) {};\n", _strCurrentClass);
    } else {
      PrintTable("void %s_OnPrecache(CDLLEntityClass *pdec, INDEX iUser);\n", _strCurrentClass);
    }

    if (!_bFeature_ImplementsOnWorldEnd) {
      PrintTable("void %s_OnWorldEnd(CWorld *pwo) {};\n", _strCurrentClass);
    } else {
      PrintTable("void %s_OnWorldEnd(CWorld *pwo);\n", _strCurrentClass);
    }

    if (!_bFeature_ImplementsOnWorldInit) {
      PrintTable("void %s_OnWorldInit(CWorld *pwo) {};\n", _strCurrentClass);
    } else {
      PrintTable("void %s_OnWorldInit(CWorld *pwo);\n", _strCurrentClass);
    }

    if (!_bFeature_ImplementsOnWorldTick) {
      PrintTable("void %s_OnWorldTick(CWorld *pwo) {};\n", _strCurrentClass);
    } else {
      PrintTable("void %s_OnWorldTick(CWorld *pwo);\n", _strCurrentClass);
    }

    if (!_bFeature_ImplementsOnWorldRender) {
      PrintTable("void %s_OnWorldRender(CWorld *pwo) {};\n", _strCurrentClass);
    } else {
      PrintTable("void %s_OnWorldRender(CWorld *pwo);\n", _strCurrentClass);
    }

    PrintTable("ENTITY_CLASSDEFINITION(%s, %s, %s, %s, 0x%08x);\n",
      _strCurrentClass, _strCurrentBase, 
      _strCurrentDescription, _strCurrentThumbnail, _iCurrentClassID);
    PrintTable("DECLARE_CTFILENAME(_fnm%s_tbn, %s);\n", _strCurrentClass, _strCurrentThumbnail);

    PrintDecl("};\n");
  }
  ;

class_optexport
  : k_class { $$ = $1; _bClassIsExported = 0; }
  | k_class k_export { $$ = $1+" DECL_DLL "; _bClassIsExported = 1; }
  ;

opt_features
  : /*null */
  | k_features {
    _bFeature_ImplementsOnWorldInit = 0;
    _bFeature_ImplementsOnWorldEnd = 0;
    _bFeature_ImplementsOnWorldTick = 0;
    _bFeature_ImplementsOnWorldRender = 0;
    _bFeature_ImplementsOnInitClass = 0;
    _bFeature_ImplementsOnEndClass = 0;
    _bFeature_ImplementsOnPrecache = 0;
    _bFeature_AbstractBaseClass = 0;
    _bFeature_CanBePredictable = 0;
  }features_list ';'
  ;
features_list 
  : feature
  | features_list ',' feature
  ;
feature
  : c_string {
    if (strcmp($1.strString, "\"AbstractBaseClass\"")==0) {
      _bFeature_AbstractBaseClass = 1;
    } else if (strcmp($1.strString, "\"IsTargetable\"")==0) {
      PrintDecl("virtual BOOL IsTargetable(void) const { return TRUE; };\n");
    } else if (strcmp($1.strString, "\"NotSentOverNet\"")==0) {
      PrintDecl("virtual BOOL IsSentOverNet(void) const { return FALSE; };\n");
    } else if (strcmp($1.strString, "\"IsImportant\"")==0) {
      PrintDecl("virtual BOOL IsImportant(void) const { return TRUE; };\n");
    } else if (strcmp($1.strString, "\"HasName\"")==0) {
      PrintDecl(
        "virtual const CTString &GetName(void) const { return m_strName; };\n");
    } else if (strcmp($1.strString, "\"CanBePredictable\"")==0) {
      PrintDecl(
        "virtual CEntity *GetPredictionPair(void) { return m_penPrediction; };\n");
      PrintDecl(
        "virtual void SetPredictionPair(CEntity *penPair) { m_penPrediction = penPair; };\n");
      _bFeature_CanBePredictable = 1;
    } else if (strcmp($1.strString, "\"HasDescription\"")==0) {
      PrintDecl(
        "virtual const CTString &GetDescription(void) const { return m_strDescription; };\n");
    } else if (strcmp($1.strString, "\"HasTarget\"")==0) {
      PrintDecl(
        "virtual CEntity *GetTarget(void) const { return m_penTarget; };\n");
    } else if (strcmp($1.strString, "\"ImplementsOnInitClass\"")==0) {
      _bFeature_ImplementsOnInitClass = 1;
    } else if (strcmp($1.strString, "\"ImplementsOnEndClass\"")==0) {
      _bFeature_ImplementsOnEndClass = 1;
    } else if (strcmp($1.strString, "\"ImplementsOnPrecache\"")==0) {
      _bFeature_ImplementsOnPrecache = 1;
    } else if (strcmp($1.strString, "\"ImplementsOnWorldInit\"")==0) {
      _bFeature_ImplementsOnWorldInit = 1;
    } else if (strcmp($1.strString, "\"ImplementsOnWorldEnd\"")==0) {
      _bFeature_ImplementsOnWorldEnd = 1;
    } else if (strcmp($1.strString, "\"ImplementsOnWorldTick\"")==0) {
      _bFeature_ImplementsOnWorldTick = 1;
    } else if (strcmp($1.strString, "\"ImplementsOnWorldRender\"")==0) {
      _bFeature_ImplementsOnWorldRender = 1;
    } else {
      yyerror((SType("Unknown feature: ")+$1).strString);
    }
  }
  ;

opt_internal_properties
  : /* null */
  | '{' internal_property_list '}'
  ;
internal_property_list
  : /* null */
  | internal_property_list internal_property
  ;
internal_property
  : any_type identifier ';' { 
    PrintDecl("%s %s;\n", $1.strString, $2.strString);
  }
  ;

/*/////////////////////////////////////////////////////////
 * Property declarations
 */

property_declaration_list
  : empty_property_declaration_list {
    DeclareFeatureProperties(); // this won't work, but at least it will generate an error!!!!
    PrintTable("  CEntityProperty()\n};\n");
    PrintTable("#define %s_propertiesct 0\n", _strCurrentClass);
    PrintTable("\n");
    PrintTable("\n");
  }
  | nonempty_property_declaration_list opt_comma {
    DeclareFeatureProperties();
    PrintTable("};\n");
    PrintTable("#define %s_propertiesct ARRAYCOUNT(%s_properties)\n", 
      _strCurrentClass, _strCurrentClass);
    PrintTable("\n");
  }
  ;
nonempty_property_declaration_list
  : property_declaration
  | nonempty_property_declaration_list ',' property_declaration
  ;
empty_property_declaration_list
  : /* null */
  ;

property_declaration
  : property_id property_type property_identifier property_wed_name_opt property_default_opt property_flags_opt {
    int iPropertyID = atoi(_strCurrentPropertyID);
    if (iPropertyID > 255) {     
      yyerror((SType("property id greater then 255, property: ")+$3).strString);
    }

    PrintTable(" CEntityProperty(%s, %s, (0x%08x<<8)+%s, offsetof(%s, %s), %s, %s, %s, %s),\n",
      _strCurrentPropertyPropertyType,
      _strCurrentPropertyEnumType,
      _iCurrentClassID,
      _strCurrentPropertyID,
      _strCurrentClass,
      _strCurrentPropertyIdentifier,
      _strCurrentPropertyName,
      _strCurrentPropertyShortcut,
      _strCurrentPropertyColor,
      _strCurrentPropertyFlags);
    PrintDecl("  %s %s;\n",
      _strCurrentPropertyDataType,
      _strCurrentPropertyIdentifier
      );

    if (strlen(_strCurrentPropertyDefaultCode)>0) {
      PrintImpl("  %s\n", _strCurrentPropertyDefaultCode);
    }
  }
  ;

property_id : c_int { _strCurrentPropertyID = $1.strString; };
property_identifier : identifier { _strCurrentPropertyIdentifier = $1.strString; };

property_type
  : k_enum identifier {
    _strCurrentPropertyPropertyType = "CEntityProperty::EPT_ENUM"; 
    _strCurrentPropertyEnumType = (SType("&")+$2+"_enum").strString; 
    _strCurrentPropertyDataType = (SType("enum ")+$2.strString).strString;
  }
  | k_FLAGS identifier {
    _strCurrentPropertyPropertyType = "CEntityProperty::EPT_FLAGS"; 
    _strCurrentPropertyEnumType = (SType("&")+$2+"_enum").strString; 
    _strCurrentPropertyDataType = "ULONG";
  }
  | k_CTString {
    _strCurrentPropertyPropertyType = "CEntityProperty::EPT_STRING"; 
    _strCurrentPropertyEnumType = "NULL"; 
    _strCurrentPropertyDataType = "CTString";
  }
  | k_CTStringTrans {
    _strCurrentPropertyPropertyType = "CEntityProperty::EPT_STRINGTRANS"; 
    _strCurrentPropertyEnumType = "NULL"; 
    _strCurrentPropertyDataType = "CTStringTrans";
  }
  | k_CTFileName {
    _strCurrentPropertyPropertyType = "CEntityProperty::EPT_FILENAME"; 
    _strCurrentPropertyEnumType = "NULL"; 
    _strCurrentPropertyDataType = "CTFileName";
  }
  | k_CTFileNameNoDep {
    _strCurrentPropertyPropertyType = "CEntityProperty::EPT_FILENAMENODEP"; 
    _strCurrentPropertyEnumType = "NULL"; 
    _strCurrentPropertyDataType = "CTFileNameNoDep";
  }
  | k_BOOL {
    _strCurrentPropertyPropertyType = "CEntityProperty::EPT_BOOL"; 
    _strCurrentPropertyEnumType = "NULL"; 
    _strCurrentPropertyDataType = "BOOL";
  }
  | k_COLOR {
    _strCurrentPropertyPropertyType = "CEntityProperty::EPT_COLOR"; 
    _strCurrentPropertyEnumType = "NULL"; 
    _strCurrentPropertyDataType = "COLOR";
  }
  | k_FLOAT {
    _strCurrentPropertyPropertyType = "CEntityProperty::EPT_FLOAT"; 
    _strCurrentPropertyEnumType = "NULL"; 
    _strCurrentPropertyDataType = "FLOAT";
  }
  | k_INDEX {
    _strCurrentPropertyPropertyType = "CEntityProperty::EPT_INDEX"; 
    _strCurrentPropertyEnumType = "NULL"; 
    _strCurrentPropertyDataType = "INDEX";
  }
  | k_TIME { /* [Cecil] Expanded timer type */
    _strCurrentPropertyPropertyType = "CEntityProperty::EPT_FLOAT"; 
    _strCurrentPropertyEnumType = "NULL"; 
    _strCurrentPropertyDataType = "TIME";
  }
  | k_RANGE {
    _strCurrentPropertyPropertyType = "CEntityProperty::EPT_RANGE"; 
    _strCurrentPropertyEnumType = "NULL"; 
    _strCurrentPropertyDataType = "RANGE";
  }
  | k_CEntityPointer {
    _strCurrentPropertyPropertyType = "CEntityProperty::EPT_ENTITYPTR"; 
    _strCurrentPropertyEnumType = "NULL"; 
    _strCurrentPropertyDataType = "CEntityPointer";
  }
  | k_CModelObject {
    _strCurrentPropertyPropertyType = "CEntityProperty::EPT_MODELOBJECT"; 
    _strCurrentPropertyEnumType = "NULL"; 
    _strCurrentPropertyDataType = "CModelObject";
  }
  | k_CModelInstance {
    _strCurrentPropertyPropertyType = "CEntityProperty::EPT_MODELINSTANCE"; 
    _strCurrentPropertyEnumType = "NULL"; 
    _strCurrentPropertyDataType = "CModelInstance";
  }
  | k_CAnimObject {
    _strCurrentPropertyPropertyType = "CEntityProperty::EPT_ANIMOBJECT"; 
    _strCurrentPropertyEnumType = "NULL"; 
    _strCurrentPropertyDataType = "CAnimObject";
  }
  | k_CSoundObject {
    _strCurrentPropertyPropertyType = "CEntityProperty::EPT_SOUNDOBJECT"; 
    _strCurrentPropertyEnumType = "NULL"; 
    _strCurrentPropertyDataType = "CSoundObject";
  }
  | k_CPlacement3D {
    _strCurrentPropertyPropertyType = "CEntityProperty::EPT_PLACEMENT3D"; 
    _strCurrentPropertyEnumType = "NULL"; 
    _strCurrentPropertyDataType = "CPlacement3D";
  }
  | k_FLOATaabbox3D {
    _strCurrentPropertyPropertyType = "CEntityProperty::EPT_FLOATAABBOX3D"; 
    _strCurrentPropertyEnumType = "NULL"; 
    _strCurrentPropertyDataType = "FLOATaabbox3D";
  }
  | k_FLOATmatrix3D {
    _strCurrentPropertyPropertyType = "CEntityProperty::EPT_FLOATMATRIX3D"; 
    _strCurrentPropertyEnumType = "NULL"; 
    _strCurrentPropertyDataType = "FLOATmatrix3D";
  }
  | k_FLOATquat3D {
    _strCurrentPropertyPropertyType = "CEntityProperty::EPT_FLOATQUAT3D"; 
    _strCurrentPropertyEnumType = "NULL"; 
    _strCurrentPropertyDataType = "FLOATquat3D";
  }
  | k_ANGLE {
    _strCurrentPropertyPropertyType = "CEntityProperty::EPT_ANGLE"; 
    _strCurrentPropertyEnumType = "NULL"; 
    _strCurrentPropertyDataType = "ANGLE";
  }
  | k_ANGLE3D {
    _strCurrentPropertyPropertyType = "CEntityProperty::EPT_ANGLE3D"; 
    _strCurrentPropertyEnumType = "NULL"; 
    _strCurrentPropertyDataType = "ANGLE3D";
  }
  | k_FLOAT3D {
    _strCurrentPropertyPropertyType = "CEntityProperty::EPT_FLOAT3D"; 
    _strCurrentPropertyEnumType = "NULL"; 
    _strCurrentPropertyDataType = "FLOAT3D";
  }
  | k_FLOATplane3D {
    _strCurrentPropertyPropertyType = "CEntityProperty::EPT_FLOATplane3D"; 
    _strCurrentPropertyEnumType = "NULL"; 
    _strCurrentPropertyDataType = "FLOATplane3D";
  }
  | k_ILLUMINATIONTYPE {
    _strCurrentPropertyPropertyType = "CEntityProperty::EPT_ILLUMINATIONTYPE"; 
    _strCurrentPropertyEnumType = "NULL"; 
    _strCurrentPropertyDataType = "ILLUMINATIONTYPE";
  }
  | k_ANIMATION {
    _strCurrentPropertyPropertyType = "CEntityProperty::EPT_ANIMATION"; 
    _strCurrentPropertyEnumType = "NULL"; 
    _strCurrentPropertyDataType = "ANIMATION";
  }
  ;

property_wed_name_opt
  : /* null */ {
    _strCurrentPropertyName = "\"\""; 
    _strCurrentPropertyShortcut = "0"; 
    _strCurrentPropertyColor = "0"; // this won't be rendered anyway
  }
  | c_string property_shortcut_opt property_color_opt {
    _strCurrentPropertyName = $1.strString; 
  }
  ;
property_shortcut_opt
  : /* null */ {
    _strCurrentPropertyShortcut = "0"; 
  }
  | c_char {
    _strCurrentPropertyShortcut = $1.strString; 
  }

property_color_opt
  : /* null */ {
    _strCurrentPropertyColor = "0x7F0000FFUL"; // dark red
  }
  | k_COLOR '(' expression ')' {
    _strCurrentPropertyColor = $3.strString; 
  }
property_flags_opt
  : /* null */ {
    _strCurrentPropertyFlags = "0"; // dark red
  }
  | k_features '(' expression ')' {
    _strCurrentPropertyFlags = $3.strString; 
  }

property_default_opt
  : /* null */ {
    if (strcmp(_strCurrentPropertyDataType,"CEntityPointer")==0)  {
      _strCurrentPropertyDefaultCode = (SType(_strCurrentPropertyIdentifier)+" = NULL;").strString;
    } else if (strcmp(_strCurrentPropertyDataType,"CModelObject")==0)  {
      _strCurrentPropertyDefaultCode = 
        (SType(_strCurrentPropertyIdentifier)+".SetData(NULL);\n"+
        _strCurrentPropertyIdentifier+".mo_toTexture.SetData(NULL);").strString;
    } else if (strcmp(_strCurrentPropertyDataType,"CModelInstance")==0)  {
      _strCurrentPropertyDefaultCode = 
        (SType(_strCurrentPropertyIdentifier)+".Clear();\n").strString;
    } else if (strcmp(_strCurrentPropertyDataType,"CAnimObject")==0)  {
      _strCurrentPropertyDefaultCode = 
        (SType(_strCurrentPropertyIdentifier)+".SetData(NULL);\n").strString;
    } else if (strcmp(_strCurrentPropertyDataType,"CSoundObject")==0)  {
      _strCurrentPropertyDefaultCode = 
        (SType(_strCurrentPropertyIdentifier)+".SetOwner(this);\n"+
         _strCurrentPropertyIdentifier+".Stop(FALSE);").strString;
    } else {
      yyerror("this kind of property must have default value");
      _strCurrentPropertyDefaultCode = "";
    }
  }
  | '=' property_default_expression {
    if (strcmp(_strCurrentPropertyDataType,"CEntityPointer")==0)  {
      _strCurrentPropertyDefaultCode = (SType(_strCurrentPropertyIdentifier)+" = NULL;").strString;
      yyerror("CEntityPointer type properties always default to NULL");
    } else {
      _strCurrentPropertyDefaultCode = (SType(_strCurrentPropertyIdentifier)+" = "+$2.strString+";").strString;
    }
  }
  ;
property_default_expression
  : c_int|c_float|c_bool|c_char|c_string
  | identifier {$$ = $1 + " ";}
  | identifier '(' expression ')' {$$ = $1+$2+$3+$4;}
  | type_keyword '(' expression ')' {$$ = $1+$2+$3+$4;}
  | '-' property_default_expression {$$ = $1+$2;}
  | '(' expression ')' {$$ = $1+$2+$3;}
  ;

/*/////////////////////////////////////////////////////////
 * Component declarations
 */
component_declaration_list
  : empty_component_declaration_list {
    PrintTable("  CEntityComponent()\n};\n");
    PrintTable("#define %s_componentsct 0\n", _strCurrentClass);
    PrintTable("\n");
    PrintTable("\n");
  }
  | nonempty_component_declaration_list opt_comma {
    PrintTable("};\n");
    PrintTable("#define %s_componentsct ARRAYCOUNT(%s_components)\n", 
      _strCurrentClass, _strCurrentClass);
    PrintTable("\n");
  }
  ;
nonempty_component_declaration_list
  : component_declaration
  | nonempty_component_declaration_list ',' component_declaration
  ;
empty_component_declaration_list
  : /* null */
  ;

component_declaration
  : component_id opt_component_flags component_type component_identifier component_filename {
  PrintTable("#define %s ((0x%08x<<8)+%s)\n",
      _strCurrentComponentIdentifier,
      _iCurrentClassID,
      _strCurrentComponentID);
    PrintTable(" CEntityComponent(%s, %s, %d, \"%s%s\" %s),\n",
      _strCurrentComponentType,
      _strCurrentComponentIdentifier,
      _ulCurrentComponentFlags,
      "EF","NM",
      _strCurrentComponentFileName);
  }
  ;

component_id : c_int { _strCurrentComponentID = $1.strString; };
component_identifier : identifier { _strCurrentComponentIdentifier = $1.strString; };
component_filename : c_string { _strCurrentComponentFileName = $1.strString; };

component_type
  : k_model   { _strCurrentComponentType = "ECT_MODEL"; }
  | k_texture { _strCurrentComponentType = "ECT_TEXTURE"; }
  | k_sound   { _strCurrentComponentType = "ECT_SOUND"; }
  | k_class   { _strCurrentComponentType = "ECT_CLASS"; }
  | k_skamodel { _strCurrentComponentType = "ECT_SKAMODEL";}
  ;

opt_component_flags
  : undefined_component_flags
  | component_flags_list
  ;

undefined_component_flags
  : /*null*/   { _ulCurrentComponentFlags = 0; }
  ;

component_flags_list
  : component_flags component_flags_list
  | component_flags
  ;

component_flags
  : k_editor   { _ulCurrentComponentFlags |= CF_EDITOR; }
  ;

/*/////////////////////////////////////////////////////////
 * Functions
 */
function_list
  : { $$ = "";}
  | function_list function_implementation {$$ = $1+$2;}
  ;

function_implementation
  : opt_export opt_virtual return_type opt_tilde identifier '(' parameters_list ')' opt_const
  '{' statements '}' opt_semicolon {
    char *strReturnType = $3.strString;
    char *strFunctionHeader = ($4+$5+$6+$7+$8+$9).strString;
    char *strFunctionBody = ($10+$11+$12).strString;
    if (strcmp($5.strString, _strCurrentClass)==0) {
      if (strcmp(strReturnType+strlen(strReturnType)-4, "void")==0 ) {
        strReturnType = "";
      } else {
        yyerror("use 'void' as return type for constructors");
      }
    }
    PrintDecl(" %s %s %s %s;\n", 
      $1.strString, $2.strString, strReturnType, strFunctionHeader);
    PrintImpl("  %s %s::%s %s\n", 
      strReturnType, _strCurrentClass, strFunctionHeader, strFunctionBody);
  }
  ;
opt_tilde
  : { $$ = "";}
  | '~' { $$ = " ~ "; }
  ;

opt_export
  : { $$ = "";}
  | k_export { 
    if (_bClassIsExported) {
      $$ = ""; 
    } else {
      $$ = " DECL_DLL "; 
    }
  }
  ;

opt_const
  : { $$ = "";}
  | k_const { $$ = $1; }
  ;
opt_virtual
  : { $$ = "";}
  | k_virtual { $$ = $1; }
  ;
opt_semicolon
  : /* null */
  | ';'
  ;
parameters_list
  : { $$ = "";}
  | k_void
  | non_void_parameters_list
  ;
non_void_parameters_list
  : parameter_declaration
  | non_void_parameters_list ',' parameter_declaration {$$ = $1+$2+$3;}
  ;
parameter_declaration
  : any_type identifier { $$=$1+" "+$2; }
  ;

return_type 
  : any_type
  | k_void
  ;

any_type
  : type_keyword
  | identifier
  | k_enum identifier { $$=$1+" "+$2; }
  | any_type '*' { $$=$1+" "+$2; }
  | any_type '&' { $$=$1+" "+$2; }
  | k_void '*' { $$=$1+" "+$2; }
  | k_const any_type { $$=$1+" "+$2; }
  | k_inline any_type { $$=$1+" "+$2; }
  | k_static any_type { $$=$1+" "+$2; }
  | k_class any_type { $$=$1+" "+$2; }
  | identifier '<' any_type '>' { $$=$1+" "+$2+" "+$3+" "+$4; }
  ;


/*/////////////////////////////////////////////////////////
 * Procedures
 */
procedure_list
  : { $$ = "";}
  | procedure_list procedure_implementation {$$ = $1+$2;}
  ;

opt_override
  : { $$ = "-1"; }
  | ':' identifier ':' ':' identifier {
    $$ = SType("STATE_")+$2+"_"+$5;
  }
  ;

procedure_implementation
  : identifier '(' event_specification ')' opt_override {
    char *strProcedureName = $1.strString;
    char strInputEventType[80];
    char strInputEventName[80];
    sscanf($3.strString, "%s %s", strInputEventType, strInputEventName);

    char strStateID[256];
    char *strBaseStateID = "-1";
    if(strcmp(RemoveLineDirective(strProcedureName), "Main")==0){
      strcpy(strStateID, "1");
      if(strncmp(strInputEventType, "EVoid", 4)!=0 && _strCurrentThumbnail[2]!=0) {
        yyerror("procedure 'Main' can take input parameters only in classes without thumbnails");
      }
    } else {
      sprintf(strStateID, "0x%08x", CreateID());
    }

    sprintf(_strCurrentStateID, "STATE_%s_%s", 
      _strCurrentClass, RemoveLineDirective(strProcedureName));
    PrintDecl("#define  %s %s\n", _strCurrentStateID, strStateID);
    AddHandlerFunction(strProcedureName, strStateID, $5.strString);
    PrintImpl(
      "BOOL %s::%s(const CEntityEvent &__eeInput) {\n#undef STATE_CURRENT\n#define STATE_CURRENT %s\n", 
      _strCurrentClass, strProcedureName, _strCurrentStateID);
    PrintImpl(
      "  ASSERTMSG(__eeInput.ee_slEvent==EVENTCODE_%s, \"%s::%s expects '%s' as input!\");",
      strInputEventType, _strCurrentClass, RemoveLineDirective(strProcedureName), 
      strInputEventType);
    PrintImpl("  const %s &%s = (const %s &)__eeInput;",
      strInputEventType, strInputEventName, strInputEventType);

  } '{' statements '}' opt_semicolon {
    char *strFunctionBody = $8.strString;
    PrintImpl("%s ASSERT(FALSE); return TRUE;};", strFunctionBody);
  }
  ;

event_specification 
  : {
    $$="EVoid e";
  }
  | identifier {
    $$=$1+" e";
  }
  | identifier identifier {
    $$=$1+" "+$2;
  }
  ;

expression 
  : c_int|c_float|c_bool|c_char|c_string
  | identifier {$$ = $1 + " ";}
  | type_keyword
  | '='|'+'|'-'|'<'|'>'|'!'|'|'|'&'|'*'|'/'|'%'|'^'|'['|']'|':'|','|'.'|'?'|'~'
  | '(' ')' {$$=$1+$2;}
  | '+' '+' {$$=$1+$2;}
  | '-' '-' {$$=$1+$2;}
  | '-' '>' {$$=$1+$2;}
  | ':' ':' {$$=$1+$2;}
  | '&' '&' {$$=$1+$2;}
  | '|' '|' {$$=$1+$2;}
  | '^' '^' {$$=$1+$2;}
  | '>' '>' {$$=$1+$2;}
  | '<' '<' {$$=$1+$2;}
  | '=' '=' {$$=$1+$2;}
  | '!' '=' {$$=$1+$2;}
  | '>' '=' {$$=$1+$2;}
  | '<' '=' {$$=$1+$2;}
  | '&' '=' {$$=$1+$2;}
  | '|' '=' {$$=$1+$2;}
  | '^' '=' {$$=$1+$2;}
  | '+' '=' {$$=$1+$2;}
  | '-' '=' {$$=$1+$2;}
  | '/' '=' {$$=$1+$2;}
  | '%' '=' {$$=$1+$2;}
  | '*' '=' {$$=$1+$2;}
  | '>' '>' '=' {$$=$1+$2+$3;}
  | '<' '<' '=' {$$=$1+$2+$3;}
  | '(' expression ')' {$$ = $1+$2+$3;}
  | expression expression {$$ = $1+" "+$2;}
  ;
type_keyword
  : k_CTString|k_CTStringTrans|k_CTFileName|k_CTFileNameNoDep
  | k_BOOL|k_COLOR|k_FLOAT|k_INDEX|k_TIME|k_RANGE
  | k_CEntityPointer|k_CModelObject|k_CModelInstance|k_CAnimObject|k_CSoundObject
  | k_CPlacement3D | k_FLOATaabbox3D|k_FLOATmatrix3D| k_FLOATquat3D|k_ANGLE|k_ANIMATION|k_ILLUMINATIONTYPE
  | k_ANGLE3D|k_FLOAT3D|k_FLOATplane3D
  | k_const 
  | k_static
  ;
case_constant_expression
  : c_int|c_float|c_bool|c_char|c_string
  | identifier {$$ = $1 + " ";}
  ;


/* Simple statements:
 */
statements
  : { $$ = "";}
  | statements statement { $$ = $1+$2; } 
  ;
statement
  : expression ';' {$$=$1+$2;}
  | k_switch '(' expression ')' '{' statements '}' {$$=$1+$2+$3+$4+$5+$6+$7;}
  | k_case case_constant_expression ':' {$$=$1+" "+$2+$3+" ";}
  | '{' statements '}' {$$=$1+$2+$3;}
  | expression '{' statements '}' {$$=$1+$2+$3+$4;}
  | statement_while
  | statement_dowhile
  | statement_for
  | statement_if
  | statement_if_else
  | statement_wait
  | statement_autowait
  | statement_waitevent
  | statement_call
  | statement_autocall
  | statement_stop
  | statement_resume
  | statement_pass
  | statement_return
  | statement_jump
  | ';'
  ;


statement_if
  : k_if '(' expression ')' '{' statements '}' {
    if ($6.bCrossesStates) {
      char strAfterIfName[80], strAfterIfID[11];
      CreateInternalHandlerFunction(strAfterIfName, strAfterIfID);
      $$ = $1+"(!"+$2+$3+$4+"){ Jump(STATE_CURRENT,"+strAfterIfID+", FALSE, EInternal());return TRUE;}"+$6+
        "Jump(STATE_CURRENT,"+strAfterIfID+", FALSE, EInternal());return TRUE;}"+
        "BOOL "+_strCurrentClass+"::"+strAfterIfName+"(const CEntityEvent &__eeInput){"+
        "\nASSERT(__eeInput.ee_slEvent==EVENTCODE_EInternal);"+
        "\n#undef STATE_CURRENT\n#define STATE_CURRENT "+strAfterIfID+"\n";
    } else {
      $$ = $1+$2+$3+$4+$5+$6+$7;
    }
  }
  ;

statement_if_else
  : k_if '(' expression ')' '{' statements '}' k_else statement {
    if ($6.bCrossesStates || $9.bCrossesStates) {
      char strAfterIfName[80], strAfterIfID[11];
      char strElseName[80], strElseID[11];
      CreateInternalHandlerFunction(strAfterIfName, strAfterIfID);
      CreateInternalHandlerFunction(strElseName, strElseID);
      $$ = $1+"(!"+$2+$3+$4+"){ Jump(STATE_CURRENT,"+strElseID+", FALSE, EInternal());return TRUE;}"+
        $6+"Jump(STATE_CURRENT,"+strAfterIfID+", FALSE, EInternal());return TRUE;}"+
        "BOOL "+_strCurrentClass+"::"+strElseName+"(const CEntityEvent &__eeInput){"+
        "\nASSERT(__eeInput.ee_slEvent==EVENTCODE_EInternal);"+
        "\n#undef STATE_CURRENT\n#define STATE_CURRENT "+strElseID+"\n"+
        $9+"Jump(STATE_CURRENT,"+strAfterIfID+", FALSE, EInternal());return TRUE;}\n"+
        "BOOL "+_strCurrentClass+"::"+strAfterIfName+"(const CEntityEvent &__eeInput){"+
        "\nASSERT(__eeInput.ee_slEvent==EVENTCODE_EInternal);"+
        "\n#undef STATE_CURRENT\n#define STATE_CURRENT "+strAfterIfID+"\n";
    } else {
      $$ = $1+$2+$3+$4+$5+$6+$7+$8+" "+$9;
    }
  }
  ;

statement_while
  : k_while '(' expression ')' {
    if (strlen(_strInLoopName)>0) {
      yyerror("Nested loops are not implemented yet");
    }
  } '{' statements '}' {
    if ($7.bCrossesStates) {
      CreateInternalHandlerFunction(_strInLoopName, _strInLoopID);
      CreateInternalHandlerFunction(_strAfterLoopName, _strAfterLoopID);
      $$ = SType(GetLineDirective($1))+"Jump(STATE_CURRENT,"+_strInLoopID+", FALSE, EInternal());return TRUE;}"+
        "BOOL "+_strCurrentClass+"::"+_strInLoopName+"(const CEntityEvent &__eeInput)"+$6+
        "\nASSERT(__eeInput.ee_slEvent==EVENTCODE_EInternal);"+
        "\n#undef STATE_CURRENT\n#define STATE_CURRENT "+_strInLoopID+"\n"+
        "if(!"+$2+$3+$4+"){ Jump(STATE_CURRENT,"+_strAfterLoopID+", FALSE, EInternal());return TRUE;}"+
        $7+"Jump(STATE_CURRENT,"+_strInLoopID+", FALSE, EInternal());return TRUE;"+$8+
        "BOOL "+_strCurrentClass+"::"+_strAfterLoopName+"(const CEntityEvent &__eeInput) {"+
        "\nASSERT(__eeInput.ee_slEvent==EVENTCODE_EInternal);"+
        "\n#undef STATE_CURRENT\n#define STATE_CURRENT "+_strAfterLoopID+"\n";
    } else {
      $$ = $1+$2+$3+$4+$6+$7+$8;
    } 
    _strInLoopName[0] = 0;
  }
  ;

statement_dowhile
  : k_do '{' statements '}' {
    if (strlen(_strInLoopName)>0) {
      yyerror("Nested loops are not implemented yet");
    }
    _strInLoopName[0] = 0;
  } k_while '(' expression ')' ';' {
    if ($3.bCrossesStates) {
      CreateInternalHandlerFunction(_strInLoopName, _strInLoopID);
      CreateInternalHandlerFunction(_strAfterLoopName, _strAfterLoopID);
      $$ = SType(GetLineDirective($1))+"Jump(STATE_CURRENT,"+_strInLoopID+", FALSE, EInternal());return TRUE;}"+
        "BOOL "+_strCurrentClass+"::"+_strInLoopName+"(const CEntityEvent &__eeInput)"+$2+
        "\nASSERT(__eeInput.ee_slEvent==EVENTCODE_EInternal);"+
        "\n#undef STATE_CURRENT\n#define STATE_CURRENT "+_strInLoopID+"\n"+$3+
        "if(!"+$7+$8+$9+"){ Jump(STATE_CURRENT,"+_strAfterLoopID+", FALSE, EInternal());return TRUE;}"+
        "Jump(STATE_CURRENT,"+_strInLoopID+", FALSE, EInternal());return TRUE;"+$4+
        "BOOL "+_strCurrentClass+"::"+_strAfterLoopName+"(const CEntityEvent &__eeInput) {"+
        "\nASSERT(__eeInput.ee_slEvent==EVENTCODE_EInternal);"+
        "\n#undef STATE_CURRENT\n#define STATE_CURRENT "+_strAfterLoopID+"\n";
    } else {
      $$ = $1+$2+$3+$4+$6+$7+$8+$9+$10;
    } 
    _strInLoopName[0] = 0;
  }
  ;

statement_for
  : k_for '(' expression ';' expression ';' expression ')' {
    if (strlen(_strInLoopName)>0) {
      yyerror("Nested loops are not implemented yet");
    }
  } '{' statements '}' {
    if ($11.bCrossesStates) {
      CreateInternalHandlerFunction(_strInLoopName, _strInLoopID);
      CreateInternalHandlerFunction(_strAfterLoopName, _strAfterLoopID);
      yyerror("For loops across states are not supported");
    } else {
      $$ = $1+$2+$3+$4+$5+$6+$7+$8+$10+$11+$12;
    } 
    _strInLoopName[0] = 0;
  }
  ;

statement_wait
  : k_wait wait_expression {
      if (!_bInProcedure) {
        yyerror("Cannot have 'wait' in functions");
      }
      CreateInternalHandlerFunction(_strInWaitName, _strInWaitID);
      CreateInternalHandlerFunction(_strAfterWaitName, _strAfterWaitID);
      _bHasOtherwise = 0;
      _bInHandler = 1;
  } '{' handlers_list '}' {
    if ($5.bCrossesStates) {
      yyerror("'wait' statements must not be nested");
      $$ = "";
    } else {
      SType stDefault;
      if (!_bHasOtherwise) {
        stDefault = SType("default: return FALSE; break;");
      } else {
        stDefault = SType("");
      }

      $$ = SType(GetLineDirective($1))+$2+";\n"+
        "Jump(STATE_CURRENT, "+_strInWaitID+", FALSE, EBegin());return TRUE;}"+
        "BOOL "+_strCurrentClass+"::"+_strInWaitName+"(const CEntityEvent &__eeInput) {"+
        "\n#undef STATE_CURRENT\n#define STATE_CURRENT "+_strInWaitID+"\n"+
        "switch(__eeInput.ee_slEvent)"+$4+$5+stDefault+$6+
        "return TRUE;}BOOL "+_strCurrentClass+"::"+_strAfterWaitName+"(const CEntityEvent &__eeInput){"+
        "\nASSERT(__eeInput.ee_slEvent==EVENTCODE_EInternal);"+
        "\n#undef STATE_CURRENT\n#define STATE_CURRENT "+_strAfterWaitID+"\n";
      $$.bCrossesStates = 1;
      _bInHandler = 0;
    }
  }
  ;
statement_autowait
  : k_autowait wait_expression ';' {
    if (!_bInProcedure) {
      yyerror("Cannot have 'autowait' in functions");
    }
    CreateInternalHandlerFunction(_strInWaitName, _strInWaitID);
    CreateInternalHandlerFunction(_strAfterWaitName, _strAfterWaitID);
    _bHasOtherwise = 0;

    $$ = SType(GetLineDirective($1))+$2+";\n"+
      "Jump(STATE_CURRENT, "+_strInWaitID+", FALSE, EBegin());return TRUE;}"+
      "BOOL "+_strCurrentClass+"::"+_strInWaitName+"(const CEntityEvent &__eeInput) {"+
      "\n#undef STATE_CURRENT\n#define STATE_CURRENT "+_strInWaitID+"\n"+
      "switch(__eeInput.ee_slEvent) {"+
      "case EVENTCODE_EBegin: return TRUE;"+
      "case EVENTCODE_ETimer: Jump(STATE_CURRENT,"+_strAfterWaitID+", FALSE, EInternal()); return TRUE;"+
      "default: return FALSE; }}"+
      "BOOL "+_strCurrentClass+"::"+_strAfterWaitName+"(const CEntityEvent &__eeInput){"+
      "\nASSERT(__eeInput.ee_slEvent==EVENTCODE_EInternal);"+
      "\n#undef STATE_CURRENT\n#define STATE_CURRENT "+_strAfterWaitID+"\n"+$3;
    $$.bCrossesStates = 1;
  }
  ;

statement_waitevent
  : k_waitevent wait_expression identifier opt_eventvar ';' {
    if (!_bInProcedure) {
      yyerror("Cannot have 'autocall' in functions");
    }
    CreateInternalHandlerFunction(_strInWaitName, _strInWaitID);
    CreateInternalHandlerFunction(_strAfterWaitName, _strAfterWaitID);
    _bHasOtherwise = 0;

    $$ = SType(GetLineDirective($1))+$2+";\n"+
      "Jump(STATE_CURRENT, "+_strInWaitID+", FALSE, EBegin());return TRUE;}"+
      "BOOL "+_strCurrentClass+"::"+_strInWaitName+"(const CEntityEvent &__eeInput) {"+
      "\n#undef STATE_CURRENT\n#define STATE_CURRENT "+_strInWaitID+"\n"+
      "switch(__eeInput.ee_slEvent) {"+
      "case EVENTCODE_EBegin: return TRUE;"+
      "case EVENTCODE_"+$3+": Jump(STATE_CURRENT,"+_strAfterWaitID+", FALSE, __eeInput); return TRUE;"+
      "default: return FALSE; }}"+
      "BOOL "+_strCurrentClass+"::"+_strAfterWaitName+"(const CEntityEvent &__eeInput){"+
      "\n#undef STATE_CURRENT\n#define STATE_CURRENT "+_strAfterWaitID+"\n"+
      "const "+$3+"&"+$4+"= ("+$3+"&)__eeInput;\n"+$5;
    $$.bCrossesStates = 1;
  }
  ;


opt_eventvar 
  : {
    $$ = SType("__e");
  }
  | identifier {
    $$ = $1;
  }

statement_autocall
  : k_autocall jumptarget '(' event_expression ')' identifier opt_eventvar ';' {
    if (!_bInProcedure) {
      yyerror("Cannot have 'autocall' in functions");
    }
    CreateInternalHandlerFunction(_strInWaitName, _strInWaitID);
    CreateInternalHandlerFunction(_strAfterWaitName, _strAfterWaitID);
    _bHasOtherwise = 0;

    $$ = SType(GetLineDirective($1))+$2+";\n"+
      "Jump(STATE_CURRENT, "+_strInWaitID+", FALSE, EBegin());return TRUE;}"+
      "BOOL "+_strCurrentClass+"::"+_strInWaitName+"(const CEntityEvent &__eeInput) {"+
      "\n#undef STATE_CURRENT\n#define STATE_CURRENT "+_strInWaitID+"\n"+
      "switch(__eeInput.ee_slEvent) {"+
      "case EVENTCODE_EBegin: Call"+$3+"STATE_CURRENT, "+$2+", "+$4+$5+";return TRUE;"+
      "case EVENTCODE_"+$6+": Jump(STATE_CURRENT,"+_strAfterWaitID+", FALSE, __eeInput); return TRUE;"+
      "default: return FALSE; }}"+
      "BOOL "+_strCurrentClass+"::"+_strAfterWaitName+"(const CEntityEvent &__eeInput){"+
      "\n#undef STATE_CURRENT\n#define STATE_CURRENT "+_strAfterWaitID+"\n"+
      "const "+$6+"&"+$7+"= ("+$6+"&)__eeInput;\n"+$8;
    $$.bCrossesStates = 1;
  }
  ;

wait_expression
  : '(' ')' {
    $$ = SType("SetTimerAt(THINKTIME_NEVER)"); 
  }
  | '(' expression ')' {
    $$ = SType("SetTimerAfter")+$1+$2+$3; 
  }
  ;

statement_jump
  : k_jump jumptarget '(' event_expression ')' ';' {
    if (!_bInProcedure) {
      yyerror("Cannot have 'jump' in functions");
    }
    $$ = SType(GetLineDirective($1))+"Jump"+$3+"STATE_CURRENT, "+$2+", "+$4+$5+";return TRUE;";
  }
  ;

statement_call
  : k_call jumptarget '(' event_expression')' ';' {
    if (!_bInProcedure) {
      yyerror("Cannot have 'call' in functions");
    }
    if (!_bInHandler) {
      yyerror("'call' must be inside a 'wait' statement");
    }
    $$ = SType(GetLineDirective($1))+"Call"+$3+"STATE_CURRENT, "+$2+", "+$4+$5+";return TRUE;";
  }
  ;

event_expression
  : expression { 
    $$ = $1;
  }
  | {
    $$ = SType("EVoid()");
  }
  ;

jumptarget
  : identifier {
    $$ = SType("STATE_")+_strCurrentClass+"_"+$1+", TRUE";
  }
  | identifier ':' ':' identifier {
    $$ = SType("STATE_")+$1+"_"+$4+", FALSE";
  }
  ;

statement_stop
  : k_stop ';' {
    $$ = SType(GetLineDirective($1))+"UnsetTimer();Jump(STATE_CURRENT,"
      +_strAfterWaitID+", FALSE, EInternal());"+"return TRUE"+$2;
  }
  ;
statement_resume
  : k_resume ';' {
    $$ = SType(GetLineDirective($1))+"return TRUE"+$2;
  }
  ;
statement_pass
  : k_pass ';' {
    $$ = SType(GetLineDirective($1))+"return FALSE"+$2;
  }
  ;
statement_return
  : k_return opt_expression ';' {
    if (!_bInProcedure) {
      $$ = $1+" "+$2+$3;
    } else {
      if (strlen($2.strString)==0) {
        $2 = SType("EVoid()");
      }
      $$ = SType(GetLineDirective($1))
        +"Return(STATE_CURRENT,"+$2+");"
        +$1+" TRUE"+$3;
    }
  }
  ;
opt_expression
  : {$$ = "";}
  | expression
  ;

handler
  : k_on '(' event_specification ')' ':' '{' statements '}' opt_semicolon {
    char strInputEventType[80];
    char strInputEventName[80];
    sscanf($3.strString, "%s %s", strInputEventType, strInputEventName);

    $$ = SType("case")+$2+"EVENTCODE_"+strInputEventType+$4+$5+$6+
      "const "+strInputEventType+"&"+strInputEventName+"= ("+
      strInputEventType+"&)__eeInput;\n"+$7+$8+"ASSERT(FALSE);break;";
  }
  | k_otherwise '(' event_specification ')' ':' '{' statements '}' opt_semicolon {
    char strInputEventType[80];
    char strInputEventName[80];
    sscanf($3.strString, "%s %s", strInputEventType, strInputEventName);

    $$ = SType("default")+$5+$6+$7+$8+"ASSERT(FALSE);break;";
    _bHasOtherwise = 1;
  }
  ;
handlers_list 
  : { $$ = "";}
  | handlers_list handler { $$ = $1+$2; } 
  ;

%%

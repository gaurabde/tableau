//{{NO_DEPENDENCIES}}

/////////////////////////////////////////////////////////////////////////////
//
// version.h
//
//
//
/////////////////////////////////////////////////////////////////////////////
/*
    NOTE:
    The flags VERSION_ISBETA and VERSION_ISINTERIM are mutually exclusive.
    If both are set, isbeta has precedence.

    The default state, is Production Release in which there is no expiration
    date processing and no risk of falling over.

    During the development/release cycle, the various flags will be set as follows:
    Pre-Release
        (from branch creation to RC0: VERSION_ISBETA = 1 VERSION_ISINTERIM = 0)

    Production Release
        (during RC mode):  VERSION_ISBETA = 0  VERSION_ISINTERIM = 0

    Interim Release
        (devbuilds done between releases):  VERSION_ISBETA = 0 VERSION_ISINTERIM = 1

    The flag VERSION_EXPIRE is a base 8 date object, which can be problematic
    when some values contain leading zeros.
*/
#pragma once

#define VERSION_RINT        7000,12,0913,1719
#define VERSION_RSTR        "7000.12.0913.1719"
#define VERSION_ASSET_STR   "7.0.8"
#define VERSION_EXTERNAL_STR   "7.0.8"
#define VERSION_STR         "7.0"

#define VERSION_ISBETA      0
#define VERSION_ISINTERIM     0
#define VERSION_EXPIRE      
#define VERSION_CODENAME    _T("Samurai")

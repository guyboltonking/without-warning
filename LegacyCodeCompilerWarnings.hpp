#pragma once

/*! \file
    Macros to disable warnings in legacy code when the risk of fixing the
    warning condition is too great */

#define POTENTIAL_BUG__CONVERSION_LOSES_DATA \
   __pragma(warning(suppress: 4244))

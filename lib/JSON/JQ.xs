/***************************************************************************
    copyright            : (C) 2021 - 2021 by Dongxu Ma
    email                : dongxu@cpan.org

    This library is free software; you can redistribute it and/or modify
    it under MIT license. Refer to LICENSE within the package root folder
    for full copyright.

 ***************************************************************************/

#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "jq.h"
#include "jv.h"

// utility functions for type marshaling
// they are not XS code
jv my_jv_input(void * arg) {
    if (arg == NULL) {
        return jv_null();
    }
    SV * const tmp_sv = arg;
    SvGETMAGIC(tmp_sv);
    if(svTYPE(tmp_sv) == SVt_NULL) {
        // null
        return jv_null();
    }
    else if(SvROK(tmp_sv) && SvTYPE(SvRV(tmp_sv)) < SVt_PVAV) {
        // boolean: \0 or \1
        return jv_bool((bool)SvTRUE(SvRV(tmp_sv)));
    }
    else if(SvIOK(tmp_sv)) {
        // integer
        return jv_number((int)SvIV(tmp_sv));
    }
    else if(SvUOK(tmp_sv)) {
        // unsigned int
        return jv_number((unsigned int)SvUV(tmp_sv));
    }
    else if(SvNOK(tmp_sv)) {
        // double
        return jv_number((double)SvNV(tmp_sv));
    }
    else if(SvPOK(tmp_sv)) {
        // string
        STRLEN len;
        char * string = SvPVutf8(tmp_sv, len);
        return jv_string_sized(string, len);
    }
    else if(SvROK(tmp_sv) && SvTYPE(SvRV(tmp_sv)) == SVt_PVAV) {
        // array
        jv j_array = jv_array();
        AV * p_array = (AV *)SvRV(tmp_sv);
        SSize_t n = av_len(p_array);
        if (n < 0) {
            return j_array;
        }
        for (SSize_t i = 0; i <= n; i++) {
            j_array = jv_array_append(j_array, my_jv_input(*av_fetch(p_array, i, 0)));
        }
        return j_array;
    }
    else if(SvROK(tmp_sv) && SvTYPE(SvRV(tmp_sv)) == SVt_PVHV) {
        // hash
        jv j_hash = jv_object();
        HV * p_hash = (HV *)SvRV(tmp_sv);
        I32 n = hv_iterinit(p_hash);
        for (I32 i = 0; i < n; i++) {
            char * k = NULL;
            I32 l = 0;
            SV * v = hv_iternextsv(p_hash, &k, &l);
            j_hash = jv_object_set(j_hash, jv_string_sized(k, l), my_jv_input(v));
        }
        return j_hash;
    }
    else {
        // not supported
        croak("cannot convert perl object to json format: SvTYPE == %s", SvTYPE(tmp_sv));
    }
    // NOREACH
}

void * my_jv_output(jv arg) {
    jv_kind kind = jv_get_kind(arg);
}

TYPEMAP: <<EOL
jq_state *         T_PTRREF
EOL

MODULE = JSON::JQ              PACKAGE = JSON::JQ

void
_error_cb(error_msgs, error)
    T_AVREF_REFCOUNT_FIXED error_msgs
    jv error

jq_state *
init(script_cont, error_msgs, compile_opts, library_paths)
    const char * script_cont
    T_AVREF_REFCOUNT_FIXED error_msgs
    T_HVREF_REFCOUNT_FIXED compile_opts
    T_AVREF_REFCOUNT_FIXED library_paths
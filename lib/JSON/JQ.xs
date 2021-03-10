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
#define JQ_VERSION "1.6"

// utility functions for type marshaling
// they are not XS code
jv my_jv_input(pTHX_ void * arg) {
    if (arg == NULL) {
        return jv_null();
    }
    SV * const p_sv = arg;
    SvGETMAGIC(p_sv);
    if(SvTYPE(p_sv) == SVt_NULL) {
        // null
        return jv_null();
    }
    else if(SvROK(p_sv) && SvTYPE(SvRV(p_sv)) < SVt_PVAV) {
        // boolean: \0 or \1, also works for $JSON::true, $JSON::false
        // TODO: map with $JSON::true and $JSON::false directly
        return jv_bool((bool)SvTRUE(SvRV(p_sv)));
    }
    else if(SvIOK(p_sv)) {
        // integer
        return jv_number((int)SvIV(p_sv));
    }
    else if(SvUOK(p_sv)) {
        // unsigned int
        return jv_number((unsigned int)SvUV(p_sv));
    }
    else if(SvNOK(p_sv)) {
        // double
        return jv_number((double)SvNV(p_sv));
    }
    else if(SvPOK(p_sv)) {
        // string
        STRLEN len;
        char * p_pv = SvPVutf8(p_sv, len);
        return jv_string_sized(p_pv, len);
    }
    else if(SvROK(p_sv) && SvTYPE(SvRV(p_sv)) == SVt_PVAV) {
        // array
        jv jval = jv_array();
        AV * p_av = (AV *)SvRV(p_sv);
        SSize_t len = av_len(p_av);
        if (len < 0) {
            return jval;
        }
        for (SSize_t i = 0; i <= len; i++) {
            jval = jv_array_append(jval, my_jv_input(aTHX_ *av_fetch(p_av, i, 0)));
        }
        return jval;
    }
    else if(SvROK(p_sv) && SvTYPE(SvRV(p_sv)) == SVt_PVHV) {
        // hash
        jv jval = jv_object();
        HV * p_hv = (HV *)SvRV(p_sv);
        I32 len = hv_iterinit(p_hv);
        for (I32 i = 0; i < len; i++) {
            char * key = NULL;
            I32 klen = 0;
            SV * val = hv_iternextsv(p_hv, &key, &klen);
            jval = jv_object_set(jval, jv_string_sized(key, klen), my_jv_input(aTHX_ val));
        }
        return jval;
    }
    else {
        // not supported
        croak("cannot convert perl object to json format: SvTYPE == %i", SvTYPE(p_sv));
    }
    // NOREACH
}

void * my_jv_output(pTHX_ jv jval) {
    jv_kind kind = jv_get_kind(jval);
    if(kind == JV_KIND_NULL) {
        // null
        return newSV(0);
    }
    else if(kind == JV_KIND_FALSE) {
        // boolean: false
        return get_sv("JSON::false", 0);
    }
    else if(kind == JV_KIND_TRUE) {
        // boolean: true
        return get_sv("JSON::true", 0);
    }
    else if(kind == JV_KIND_NUMBER) {
        // number
        double val = jv_number_value(jval);
        SV * p_sv = newSV(0);
        if(jv_is_integer(jval)) {
            sv_setiv(p_sv, (int)val);
        }
        else {
            sv_setnv(p_sv, val);
        }
        return p_sv;
    }
    else if(kind == JV_KIND_STRING) {
        // string
        return newSVpvn_utf8(jv_string_value(jval), jv_string_length_bytes(jval), 1);
    }
    else if(kind == JV_KIND_ARRAY) {
        // array
        AV * p_av = newAV();
        SSize_t len = (SSize_t)jv_array_length(jv_copy(jval));
        av_extend(p_av, len - 1);
        for (SSize_t i = 0; i < len; i++) {
            jv val = jv_array_get(jv_copy(jval), i);
            av_push(p_av, (SV *)my_jv_output(aTHX_ val));
            jv_free(val);
        }
        return p_av;
    }
    else if(kind == JV_KIND_OBJECT) {
        // hash
        HV * p_hv = newHV();
        int iter = jv_object_iter(jval);
        while(jv_object_iter_valid(jval, iter)) {
            jv key = jv_object_iter_key(jval, iter);
            jv val = jv_object_iter_value(jval, iter);
            if(jv_get_kind(key) != JV_KIND_STRING) {
                croak("cannot take non-string type as hash key: JV_KIND == %i", jv_get_kind(key));
            }
            const char * k = jv_string_value(key);
            int klen = jv_string_length_bytes(key);
            SV * v = (SV *)my_jv_output(aTHX_ val);
            hv_store(p_hv, k, klen, v, 0);
            jv_free(key);
            jv_free(val);
            iter = jv_object_iter_next(jval, iter);
        }
        return p_hv;
    }
    else {
        croak("un-supported jv object type: JV_KIND == %i", kind);
    }
    // NOREACH
}

void my_error_cb(void * errors, jv jerr) {
    dTHX;
    av_push((AV *)errors, newSVpvn_utf8(jv_string_value(jerr), jv_string_length_bytes(jerr), 1));
}

inline void assert_isa(pTHX_ SV * self) {
    if(!sv_isa(self, "JSON::JQ")) {
        croak("self is not a JSON::JQ object");
    }
}

MODULE = JSON::JQ              PACKAGE = JSON::JQ

PROTOTYPES: DISABLE

void
_init(self)
        HV * self
    INIT:
        jq_state * _jq = NULL;
        SV * sv_jq;
        HV * hv_attr;
        char * script;
    CODE:
        assert_isa(aTHX_ ST(0));
        _jq = jq_init();
        if (_jq == NULL) {
            croak("cannot malloc jq engine");
        }
        else {
            sv_jq = newSV(0);
            sv_setiv(sv_jq, PTR2IV(_jq));
            SvREADONLY_on(sv_jq);
            hv_stores(self, "_jq", sv_jq);
        }
        jq_set_error_cb(_jq, my_error_cb, SvRV(*hv_fetchs(self, "_errors", 0)));
        hv_attr = (HV *)SvRV(*hv_fetchs(self, "_attribute", 0));
        I32 len = hv_iterinit(hv_attr);
        for (I32 i = 0; i < len; i++) {
            char * key = NULL;
            I32 klen = 0;
            SV * val = hv_iternextsv(hv_attr, &key, &klen);
            jq_set_attr(_jq, jv_string_sized(key, klen), my_jv_input(aTHX_ val));
        }
        jq_set_attr(_jq, jv_string("VERSION_DIR"), jv_string(JQ_VERSION));
        script = SvPV_nolen(*hv_fetchs(self, "script", 0));
        if (!jq_compile_args(_jq, script, my_jv_input(aTHX_ *hv_fetchs(self, "variable", 0)))) {
            XSRETURN_NO;
        }
        else {
            XSRETURN_YES;
        }

void
DESTROY(self)
        HV * self
    INIT:
        jq_state * _jq = NULL;
        SV * sv_jq;
    CODE:
        assert_isa(aTHX_ ST(0));
        sv_jq = *hv_fetchs(self, "_jq", 0);
        _jq = INT2PTR(jq_state *, SvIV(sv_jq));
        if (_jq != NULL) {
            //printf("destroying jq object\n");
            jq_teardown(&_jq);
        }
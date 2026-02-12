#include <limits.h>
#include <stdbool.h>
#include <string.h>

#include "py/obj.h"
#include "py/objstr.h"
#include "py/runtime.h"

#include "umatter_core.h"
#include "umatter_config.h"

#define UMATTER_ENDPOINTS_MAX_PER_NODE (8)
#define UMATTER_CLUSTERS_MAX_PER_ENDPOINT (16)

#define UMATTER_DEVICE_TYPE_ON_OFF_LIGHT (0x0100)
#define UMATTER_CLUSTER_ON_OFF (0x0006)
#define UMATTER_CLUSTER_LEVEL_CONTROL (0x0008)
#define UMATTER_DEFAULT_DISCRIMINATOR (3840)
#define UMATTER_DEFAULT_PASSCODE (20202021U)
#define UMATTER_MIN_PASSCODE (1U)
#define UMATTER_MAX_PASSCODE (99999998U)

static mp_obj_t umatter_is_stub(void) {
    return mp_const_true;
}
static MP_DEFINE_CONST_FUN_OBJ_0(umatter_is_stub_obj, umatter_is_stub);

typedef struct _umatter_node_obj_t {
    mp_obj_base_t base;
    int handle;
    uint16_t endpoint_count;
    uint16_t endpoint_ids[UMATTER_ENDPOINTS_MAX_PER_NODE];
} umatter_node_obj_t;

typedef struct _umatter_endpoint_obj_t {
    mp_obj_base_t base;
    mp_obj_t node_obj;
    uint16_t endpoint_id;
    uint32_t device_type;
    uint16_t cluster_count;
    uint32_t cluster_ids[UMATTER_CLUSTERS_MAX_PER_ENDPOINT];
} umatter_endpoint_obj_t;

extern const mp_obj_type_t umatter_node_type;
extern const mp_obj_type_t umatter_endpoint_type;

static void umatter_raise_from_rc(int rc) {
    switch (rc) {
        case UMATTER_CORE_ERR_INVALID_ARG:
            mp_raise_ValueError(MP_ERROR_TEXT("invalid argument"));
            break;
        case UMATTER_CORE_ERR_CAPACITY:
            mp_raise_msg(&mp_type_MemoryError, MP_ERROR_TEXT("no free node slots"));
            break;
        case UMATTER_CORE_ERR_EXISTS:
            mp_raise_ValueError(MP_ERROR_TEXT("already exists"));
            break;
        case UMATTER_CORE_ERR_NOT_FOUND:
            mp_raise_msg(&mp_type_RuntimeError, MP_ERROR_TEXT("node not found"));
            break;
        case UMATTER_CORE_ERR_STATE:
            mp_raise_msg(&mp_type_RuntimeError, MP_ERROR_TEXT("invalid node state"));
            break;
        default:
            mp_raise_msg(&mp_type_RuntimeError, MP_ERROR_TEXT("core operation failed"));
            break;
    }
}

static void umatter_raise_if_closed_node(int handle) {
    if (handle <= 0) {
        mp_raise_msg(&mp_type_RuntimeError, MP_ERROR_TEXT("node is closed"));
    }
}

static bool umatter_node_has_endpoint_id(const umatter_node_obj_t *self, uint16_t endpoint_id) {
    for (size_t i = 0; i < self->endpoint_count; ++i) {
        if (self->endpoint_ids[i] == endpoint_id) {
            return true;
        }
    }
    return false;
}

static uint16_t umatter_node_next_endpoint_id(const umatter_node_obj_t *self) {
    uint16_t endpoint_id = 1;
    while (endpoint_id != 0) {
        if (!umatter_node_has_endpoint_id(self, endpoint_id)) {
            return endpoint_id;
        }
        endpoint_id++;
    }
    return 0;
}

static bool umatter_endpoint_has_cluster_id(const umatter_endpoint_obj_t *self, uint32_t cluster_id) {
    for (size_t i = 0; i < self->cluster_count; ++i) {
        if (self->cluster_ids[i] == cluster_id) {
            return true;
        }
    }
    return false;
}

static int umatter_parse_transport_mode(mp_obj_t mode_obj) {
    const char *mode = mp_obj_str_get_str(mode_obj);
    if (strcmp(mode, "none") == 0) {
        return UMATTER_CORE_TRANSPORT_NONE;
    }
    if (strcmp(mode, "wifi") == 0) {
        return UMATTER_CORE_TRANSPORT_WIFI;
    }
    if (strcmp(mode, "thread") == 0) {
        return UMATTER_CORE_TRANSPORT_THREAD;
    }
    if (strcmp(mode, "dual") == 0) {
        return UMATTER_CORE_TRANSPORT_DUAL;
    }
    mp_raise_ValueError(MP_ERROR_TEXT("invalid transport"));
    return UMATTER_CORE_TRANSPORT_NONE;
}

static mp_obj_t umatter_transport_mode_to_obj(uint8_t mode) {
    switch (mode) {
        case UMATTER_CORE_TRANSPORT_WIFI:
            return MP_OBJ_NEW_QSTR(MP_QSTR_wifi);
        case UMATTER_CORE_TRANSPORT_THREAD:
            return MP_OBJ_NEW_QSTR(MP_QSTR_thread);
        case UMATTER_CORE_TRANSPORT_DUAL:
            return MP_OBJ_NEW_QSTR(MP_QSTR_dual);
        case UMATTER_CORE_TRANSPORT_NONE:
        default:
            return MP_OBJ_NEW_QSTR(MP_QSTR_none);
    }
}

static mp_obj_t umatter_ready_reason_to_obj(int ready_reason) {
    switch (ready_reason) {
        case UMATTER_CORE_READY_REASON_READY:
            return MP_OBJ_NEW_QSTR(MP_QSTR_ready);
        case UMATTER_CORE_READY_REASON_TRANSPORT_NOT_CONFIGURED:
            return MP_OBJ_NEW_QSTR(MP_QSTR_transport_not_configured);
        case UMATTER_CORE_READY_REASON_NO_ENDPOINTS:
            return MP_OBJ_NEW_QSTR(MP_QSTR_no_endpoints);
        case UMATTER_CORE_READY_REASON_NODE_NOT_STARTED:
            return MP_OBJ_NEW_QSTR(MP_QSTR_node_not_started);
        default:
            return MP_OBJ_NEW_QSTR(MP_QSTR_unknown);
    }
}

static mp_obj_t umatter_runtime_state_from_ready_reason(int ready_reason) {
    switch (ready_reason) {
        case UMATTER_CORE_READY_REASON_READY:
            return MP_OBJ_NEW_QSTR(MP_QSTR_commissioning_ready);
        case UMATTER_CORE_READY_REASON_TRANSPORT_NOT_CONFIGURED:
            return MP_OBJ_NEW_QSTR(MP_QSTR_awaiting_transport);
        case UMATTER_CORE_READY_REASON_NO_ENDPOINTS:
            return MP_OBJ_NEW_QSTR(MP_QSTR_awaiting_endpoint);
        case UMATTER_CORE_READY_REASON_NODE_NOT_STARTED:
            return MP_OBJ_NEW_QSTR(MP_QSTR_awaiting_start);
        default:
            return MP_OBJ_NEW_QSTR(MP_QSTR_unknown);
    }
}

static mp_obj_t umatter_network_advertising_reason_to_obj(uint8_t reason_code) {
    switch (reason_code) {
        case UMATTER_CORE_NETWORK_ADVERTISING_REASON_RUNTIME_NOT_READY:
            return MP_OBJ_NEW_QSTR(MP_QSTR_runtime_not_ready);
        case UMATTER_CORE_NETWORK_ADVERTISING_REASON_NOT_INTEGRATED:
            return MP_OBJ_NEW_QSTR(MP_QSTR_not_integrated);
        case UMATTER_CORE_NETWORK_ADVERTISING_REASON_SIGNAL_PRESENT:
            return MP_OBJ_NEW_QSTR(MP_QSTR_signal_present);
        case UMATTER_CORE_NETWORK_ADVERTISING_REASON_SIGNAL_LOST:
            return MP_OBJ_NEW_QSTR(MP_QSTR_signal_lost);
        case UMATTER_CORE_NETWORK_ADVERTISING_REASON_UNKNOWN:
        default:
            return MP_OBJ_NEW_QSTR(MP_QSTR_unknown);
    }
}

static uint8_t umatter_parse_network_advertising_reason(mp_obj_t reason_obj) {
    const char *reason = mp_obj_str_get_str(reason_obj);
    if (strcmp(reason, "unknown") == 0) {
        return UMATTER_CORE_NETWORK_ADVERTISING_REASON_UNKNOWN;
    }
    if (strcmp(reason, "runtime_not_ready") == 0) {
        return UMATTER_CORE_NETWORK_ADVERTISING_REASON_RUNTIME_NOT_READY;
    }
    if (strcmp(reason, "not_integrated") == 0) {
        return UMATTER_CORE_NETWORK_ADVERTISING_REASON_NOT_INTEGRATED;
    }
    if (strcmp(reason, "signal_present") == 0) {
        return UMATTER_CORE_NETWORK_ADVERTISING_REASON_SIGNAL_PRESENT;
    }
    if (strcmp(reason, "signal_lost") == 0) {
        return UMATTER_CORE_NETWORK_ADVERTISING_REASON_SIGNAL_LOST;
    }
    mp_raise_ValueError(MP_ERROR_TEXT("invalid network advertising reason"));
    return UMATTER_CORE_NETWORK_ADVERTISING_REASON_UNKNOWN;
}

static mp_obj_t umatter_node_new_from_values(const mp_obj_type_t *type, uint16_t vendor_id, uint16_t product_id, const char *device_name) {
    int handle = 0;
    umatter_node_obj_t *self = NULL;

    handle = umatter_core_create(vendor_id, product_id, device_name);
    if (handle < 0) {
        umatter_raise_from_rc(handle);
    }

    self = mp_obj_malloc(umatter_node_obj_t, type);
    self->handle = handle;
    self->endpoint_count = 0;
    memset(self->endpoint_ids, 0, sizeof(self->endpoint_ids));
    return MP_OBJ_FROM_PTR(self);
}

static mp_obj_t umatter_node_make_new(const mp_obj_type_t *type, size_t n_args, size_t n_kw, const mp_obj_t *all_args) {
    enum { ARG_vendor_id, ARG_product_id, ARG_device_name };
    static const mp_arg_t allowed_args[] = {
        { MP_QSTR_vendor_id, MP_ARG_KW_ONLY | MP_ARG_INT, {.u_int = 0xFFF1} },
        { MP_QSTR_product_id, MP_ARG_KW_ONLY | MP_ARG_INT, {.u_int = 0x8000} },
        { MP_QSTR_device_name, MP_ARG_KW_ONLY | MP_ARG_OBJ, {.u_obj = MP_OBJ_NEW_QSTR(MP_QSTR_uMatter_Node)} },
    };
    mp_arg_val_t args[MP_ARRAY_SIZE(allowed_args)];
    const char *device_name = NULL;

    mp_arg_parse_all_kw_array(n_args, n_kw, all_args, MP_ARRAY_SIZE(allowed_args), allowed_args, args);
    device_name = mp_obj_str_get_str(args[ARG_device_name].u_obj);
    return umatter_node_new_from_values(type, (uint16_t)args[ARG_vendor_id].u_int, (uint16_t)args[ARG_product_id].u_int, device_name);
}

static mp_obj_t umatter_node_start(mp_obj_t self_in) {
    umatter_node_obj_t *self = MP_OBJ_TO_PTR(self_in);
    int rc = umatter_core_start(self->handle);
    if (rc < 0) {
        umatter_raise_from_rc(rc);
    }
    return mp_const_none;
}
static MP_DEFINE_CONST_FUN_OBJ_1(umatter_node_start_obj, umatter_node_start);

static mp_obj_t umatter_node_stop(mp_obj_t self_in) {
    umatter_node_obj_t *self = MP_OBJ_TO_PTR(self_in);
    int rc = umatter_core_stop(self->handle);
    if (rc < 0) {
        umatter_raise_from_rc(rc);
    }
    return mp_const_none;
}
static MP_DEFINE_CONST_FUN_OBJ_1(umatter_node_stop_obj, umatter_node_stop);

static mp_obj_t umatter_node_close(mp_obj_t self_in) {
    umatter_node_obj_t *self = MP_OBJ_TO_PTR(self_in);
    int rc = UMATTER_CORE_OK;

    if (self->handle > 0) {
        rc = umatter_core_destroy(self->handle);
        if (rc < 0) {
            umatter_raise_from_rc(rc);
        }
        self->handle = 0;
        self->endpoint_count = 0;
        memset(self->endpoint_ids, 0, sizeof(self->endpoint_ids));
    }

    return mp_const_none;
}
static MP_DEFINE_CONST_FUN_OBJ_1(umatter_node_close_obj, umatter_node_close);

static mp_obj_t umatter_node_is_started(mp_obj_t self_in) {
    umatter_node_obj_t *self = MP_OBJ_TO_PTR(self_in);
    int rc = umatter_core_is_started(self->handle);
    if (rc < 0) {
        umatter_raise_from_rc(rc);
    }
    return mp_obj_new_bool(rc != 0);
}
static MP_DEFINE_CONST_FUN_OBJ_1(umatter_node_is_started_obj, umatter_node_is_started);

static mp_obj_t umatter_node_set_commissioning(size_t n_args, const mp_obj_t *pos_args, mp_map_t *kw_args) {
    enum { ARG_passcode, ARG_discriminator };
    static const mp_arg_t allowed_args[] = {
        { MP_QSTR_passcode, MP_ARG_KW_ONLY | MP_ARG_INT, {.u_int = UMATTER_DEFAULT_PASSCODE} },
        { MP_QSTR_discriminator, MP_ARG_KW_ONLY | MP_ARG_INT, {.u_int = UMATTER_DEFAULT_DISCRIMINATOR} },
    };
    mp_arg_val_t args[MP_ARRAY_SIZE(allowed_args)];
    umatter_node_obj_t *self = MP_OBJ_TO_PTR(pos_args[0]);
    mp_int_t passcode = 0;
    mp_int_t discriminator = 0;
    int rc = UMATTER_CORE_OK;

    umatter_raise_if_closed_node(self->handle);
    mp_arg_parse_all(n_args - 1, pos_args + 1, kw_args, MP_ARRAY_SIZE(allowed_args), allowed_args, args);
    passcode = args[ARG_passcode].u_int;
    discriminator = args[ARG_discriminator].u_int;

    if (passcode < UMATTER_MIN_PASSCODE || (mp_uint_t)passcode > UMATTER_MAX_PASSCODE) {
        mp_raise_ValueError(MP_ERROR_TEXT("invalid passcode"));
    }
    if (discriminator < 0 || discriminator > 0x0FFF) {
        mp_raise_ValueError(MP_ERROR_TEXT("invalid discriminator"));
    }

    rc = umatter_core_set_commissioning(self->handle, (uint16_t)discriminator, (uint32_t)passcode);
    if (rc < 0) {
        umatter_raise_from_rc(rc);
    }
    return mp_const_none;
}
static MP_DEFINE_CONST_FUN_OBJ_KW(umatter_node_set_commissioning_obj, 1, umatter_node_set_commissioning);

static mp_obj_t umatter_node_commissioning(mp_obj_t self_in) {
    umatter_node_obj_t *self = MP_OBJ_TO_PTR(self_in);
    uint16_t discriminator = 0;
    uint32_t passcode = 0;
    int rc = UMATTER_CORE_OK;
    mp_obj_t tuple_items[2];

    umatter_raise_if_closed_node(self->handle);
    rc = umatter_core_get_commissioning(self->handle, &discriminator, &passcode);
    if (rc < 0) {
        umatter_raise_from_rc(rc);
    }

    tuple_items[0] = mp_obj_new_int_from_uint(discriminator);
    tuple_items[1] = mp_obj_new_int_from_uint(passcode);
    return mp_obj_new_tuple(2, tuple_items);
}
static MP_DEFINE_CONST_FUN_OBJ_1(umatter_node_commissioning_obj, umatter_node_commissioning);

static mp_obj_t umatter_node_set_transport(mp_obj_t self_in, mp_obj_t mode_in) {
    umatter_node_obj_t *self = MP_OBJ_TO_PTR(self_in);
    int transport_mode = umatter_parse_transport_mode(mode_in);
    int rc = UMATTER_CORE_OK;

    umatter_raise_if_closed_node(self->handle);
    rc = umatter_core_set_transport(self->handle, (uint8_t)transport_mode);
    if (rc < 0) {
        umatter_raise_from_rc(rc);
    }
    return mp_const_none;
}
static MP_DEFINE_CONST_FUN_OBJ_2(umatter_node_set_transport_obj, umatter_node_set_transport);

static mp_obj_t umatter_node_transport(mp_obj_t self_in) {
    umatter_node_obj_t *self = MP_OBJ_TO_PTR(self_in);
    uint8_t transport_mode = UMATTER_CORE_TRANSPORT_NONE;
    int rc = UMATTER_CORE_OK;

    umatter_raise_if_closed_node(self->handle);
    rc = umatter_core_get_transport(self->handle, &transport_mode);
    if (rc < 0) {
        umatter_raise_from_rc(rc);
    }
    return umatter_transport_mode_to_obj(transport_mode);
}
static MP_DEFINE_CONST_FUN_OBJ_1(umatter_node_transport_obj, umatter_node_transport);

static mp_obj_t umatter_node_commissioning_ready(mp_obj_t self_in) {
    umatter_node_obj_t *self = MP_OBJ_TO_PTR(self_in);
    int rc = UMATTER_CORE_OK;

    umatter_raise_if_closed_node(self->handle);
    rc = umatter_core_commissioning_ready(self->handle);
    if (rc < 0) {
        umatter_raise_from_rc(rc);
    }
    return mp_obj_new_bool(rc != 0);
}
static MP_DEFINE_CONST_FUN_OBJ_1(umatter_node_commissioning_ready_obj, umatter_node_commissioning_ready);

static mp_obj_t umatter_node_commissioning_ready_reason(mp_obj_t self_in) {
    umatter_node_obj_t *self = MP_OBJ_TO_PTR(self_in);
    int rc = UMATTER_CORE_OK;

    umatter_raise_if_closed_node(self->handle);
    rc = umatter_core_commissioning_ready_reason(self->handle);
    if (rc < 0) {
        umatter_raise_from_rc(rc);
    }
    return umatter_ready_reason_to_obj(rc);
}
static MP_DEFINE_CONST_FUN_OBJ_1(umatter_node_commissioning_ready_reason_obj, umatter_node_commissioning_ready_reason);

static mp_obj_t umatter_node_set_network_advertising(size_t n_args, const mp_obj_t *args) {
    umatter_node_obj_t *self = MP_OBJ_TO_PTR(args[0]);
    int advertising = mp_obj_is_true(args[1]) ? 1 : 0;
    uint8_t reason = UMATTER_CORE_NETWORK_ADVERTISING_REASON_UNKNOWN;
    int rc = UMATTER_CORE_OK;

    umatter_raise_if_closed_node(self->handle);
    if (n_args >= 3) {
        reason = umatter_parse_network_advertising_reason(args[2]);
    }
    rc = umatter_core_set_network_advertising(self->handle, advertising, reason);
    if (rc < 0) {
        umatter_raise_from_rc(rc);
    }
    return mp_const_none;
}
static MP_DEFINE_CONST_FUN_OBJ_VAR_BETWEEN(umatter_node_set_network_advertising_obj, 2, 3, umatter_node_set_network_advertising);

static mp_obj_t umatter_node_network_advertising(mp_obj_t self_in) {
    umatter_node_obj_t *self = MP_OBJ_TO_PTR(self_in);
    int advertising = 0;
    uint8_t reason = UMATTER_CORE_NETWORK_ADVERTISING_REASON_UNKNOWN;
    int rc = UMATTER_CORE_OK;
    mp_obj_t tuple_items[2];

    umatter_raise_if_closed_node(self->handle);
    rc = umatter_core_get_network_advertising(self->handle, &advertising, &reason);
    if (rc < 0) {
        umatter_raise_from_rc(rc);
    }
    tuple_items[0] = mp_obj_new_bool(advertising != 0);
    tuple_items[1] = umatter_network_advertising_reason_to_obj(reason);
    return mp_obj_new_tuple(2, tuple_items);
}
static MP_DEFINE_CONST_FUN_OBJ_1(umatter_node_network_advertising_obj, umatter_node_network_advertising);

static mp_obj_t umatter_node_commissioning_diagnostics(mp_obj_t self_in) {
    umatter_node_obj_t *self = MP_OBJ_TO_PTR(self_in);
    uint16_t discriminator = 0;
    uint32_t passcode = 0;
    uint8_t transport_mode = UMATTER_CORE_TRANSPORT_NONE;
    int rc = UMATTER_CORE_OK;
    int started = 0;
    int endpoint_count = 0;
    int ready_reason = UMATTER_CORE_READY_REASON_TRANSPORT_NOT_CONFIGURED;
    int network_advertising = 0;
    int network_advertising_mdns_published = 0;
    int network_advertising_mdns_last_error = 0;
    int network_advertising_manual_override = 0;
    uint8_t network_advertising_reason = UMATTER_CORE_NETWORK_ADVERTISING_REASON_UNKNOWN;
    char manual_code[12];
    char qr_code[32];
    mp_obj_t dict_obj = mp_obj_new_dict(0);

    umatter_raise_if_closed_node(self->handle);

    started = umatter_core_is_started(self->handle);
    if (started < 0) {
        umatter_raise_from_rc(started);
    }
    endpoint_count = umatter_core_endpoint_count(self->handle);
    if (endpoint_count < 0) {
        umatter_raise_from_rc(endpoint_count);
    }
    rc = umatter_core_get_commissioning(self->handle, &discriminator, &passcode);
    if (rc < 0) {
        umatter_raise_from_rc(rc);
    }
    rc = umatter_core_get_transport(self->handle, &transport_mode);
    if (rc < 0) {
        umatter_raise_from_rc(rc);
    }
    ready_reason = umatter_core_commissioning_ready_reason(self->handle);
    if (ready_reason < 0) {
        umatter_raise_from_rc(ready_reason);
    }
    rc = umatter_core_get_network_advertising_details(self->handle,
                                                      &network_advertising,
                                                      &network_advertising_reason,
                                                      &network_advertising_mdns_published,
                                                      &network_advertising_mdns_last_error,
                                                      &network_advertising_manual_override);
    if (rc < 0) {
        umatter_raise_from_rc(rc);
    }
    rc = umatter_core_get_manual_code(self->handle, manual_code, sizeof(manual_code));
    if (rc < 0) {
        umatter_raise_from_rc(rc);
    }
    rc = umatter_core_get_qr_code(self->handle, qr_code, sizeof(qr_code));
    if (rc < 0) {
        umatter_raise_from_rc(rc);
    }

    mp_obj_dict_store(dict_obj, MP_OBJ_NEW_QSTR(MP_QSTR_runtime), umatter_runtime_state_from_ready_reason(ready_reason));
    mp_obj_dict_store(dict_obj, MP_OBJ_NEW_QSTR(MP_QSTR_ready), mp_obj_new_bool(ready_reason == UMATTER_CORE_READY_REASON_READY));
    mp_obj_dict_store(dict_obj, MP_OBJ_NEW_QSTR(MP_QSTR_ready_reason), umatter_ready_reason_to_obj(ready_reason));
    mp_obj_dict_store(dict_obj, MP_OBJ_NEW_QSTR(MP_QSTR_ready_reason_code), mp_obj_new_int(ready_reason));
    mp_obj_dict_store(dict_obj, MP_OBJ_NEW_QSTR(MP_QSTR_started), mp_obj_new_bool(started != 0));
    mp_obj_dict_store(dict_obj, MP_OBJ_NEW_QSTR(MP_QSTR_endpoint_count), mp_obj_new_int(endpoint_count));
    mp_obj_dict_store(dict_obj, MP_OBJ_NEW_QSTR(MP_QSTR_transport), umatter_transport_mode_to_obj(transport_mode));
    mp_obj_dict_store(dict_obj, MP_OBJ_NEW_QSTR(MP_QSTR_network_advertising), mp_obj_new_bool(network_advertising != 0));
    mp_obj_dict_store(dict_obj, MP_OBJ_NEW_QSTR(MP_QSTR_network_advertising_reason), umatter_network_advertising_reason_to_obj(network_advertising_reason));
    mp_obj_dict_store(dict_obj,
                      MP_OBJ_NEW_QSTR(MP_QSTR_network_advertising_manual_override),
                      mp_obj_new_bool(network_advertising_manual_override != 0));
    mp_obj_dict_store(dict_obj,
                      MP_OBJ_NEW_QSTR(MP_QSTR_network_advertising_mdns_published),
                      mp_obj_new_bool(network_advertising_mdns_published != 0));
    mp_obj_dict_store(dict_obj,
                      MP_OBJ_NEW_QSTR(MP_QSTR_network_advertising_mdns_last_error),
                      mp_obj_new_int(network_advertising_mdns_last_error));
    mp_obj_dict_store(dict_obj, MP_OBJ_NEW_QSTR(MP_QSTR_discriminator), mp_obj_new_int_from_uint(discriminator));
    mp_obj_dict_store(dict_obj, MP_OBJ_NEW_QSTR(MP_QSTR_passcode), mp_obj_new_int_from_uint(passcode));
    mp_obj_dict_store(dict_obj, MP_OBJ_NEW_QSTR(MP_QSTR_manual_code), mp_obj_new_str(manual_code, strlen(manual_code)));
    mp_obj_dict_store(dict_obj, MP_OBJ_NEW_QSTR(MP_QSTR_qr_code), mp_obj_new_str(qr_code, strlen(qr_code)));
    return dict_obj;
}
static MP_DEFINE_CONST_FUN_OBJ_1(umatter_node_commissioning_diagnostics_obj, umatter_node_commissioning_diagnostics);

static mp_obj_t umatter_node_manual_code(mp_obj_t self_in) {
    umatter_node_obj_t *self = MP_OBJ_TO_PTR(self_in);
    char code[12];
    int rc = UMATTER_CORE_OK;

    umatter_raise_if_closed_node(self->handle);
    rc = umatter_core_get_manual_code(self->handle, code, sizeof(code));
    if (rc < 0) {
        umatter_raise_from_rc(rc);
    }
    return mp_obj_new_str(code, strlen(code));
}
static MP_DEFINE_CONST_FUN_OBJ_1(umatter_node_manual_code_obj, umatter_node_manual_code);

static mp_obj_t umatter_node_qr_code(mp_obj_t self_in) {
    umatter_node_obj_t *self = MP_OBJ_TO_PTR(self_in);
    char code[32];
    int rc = UMATTER_CORE_OK;

    umatter_raise_if_closed_node(self->handle);
    rc = umatter_core_get_qr_code(self->handle, code, sizeof(code));
    if (rc < 0) {
        umatter_raise_from_rc(rc);
    }
    return mp_obj_new_str(code, strlen(code));
}
static MP_DEFINE_CONST_FUN_OBJ_1(umatter_node_qr_code_obj, umatter_node_qr_code);

static mp_obj_t umatter_endpoint_make_new(const mp_obj_type_t *type, size_t n_args, size_t n_kw, const mp_obj_t *all_args) {
    (void)type;
    (void)n_args;
    (void)n_kw;
    (void)all_args;
    mp_raise_msg(&mp_type_TypeError, MP_ERROR_TEXT("use Node.add_endpoint()"));
}

static mp_obj_t umatter_node_add_endpoint(size_t n_args, const mp_obj_t *pos_args, mp_map_t *kw_args) {
    enum { ARG_endpoint_id, ARG_device_type };
    static const mp_arg_t allowed_args[] = {
        { MP_QSTR_endpoint_id, MP_ARG_KW_ONLY | MP_ARG_INT, {.u_int = -1} },
        { MP_QSTR_device_type, MP_ARG_KW_ONLY | MP_ARG_INT, {.u_int = UMATTER_DEVICE_TYPE_ON_OFF_LIGHT} },
    };
    mp_arg_val_t args[MP_ARRAY_SIZE(allowed_args)];
    umatter_node_obj_t *self = MP_OBJ_TO_PTR(pos_args[0]);
    umatter_endpoint_obj_t *endpoint = NULL;
    int endpoint_id = 0;

    umatter_raise_if_closed_node(self->handle);
    if (self->endpoint_count >= UMATTER_ENDPOINTS_MAX_PER_NODE) {
        mp_raise_msg(&mp_type_MemoryError, MP_ERROR_TEXT("no free endpoint slots"));
    }

    mp_arg_parse_all(n_args - 1, pos_args + 1, kw_args, MP_ARRAY_SIZE(allowed_args), allowed_args, args);
    endpoint_id = args[ARG_endpoint_id].u_int;
    if (endpoint_id < 0) {
        endpoint_id = umatter_node_next_endpoint_id(self);
        if (endpoint_id == 0) {
            mp_raise_msg(&mp_type_MemoryError, MP_ERROR_TEXT("no free endpoint ids"));
        }
    }
    if (endpoint_id <= 0 || endpoint_id > 0xFFFF) {
        mp_raise_ValueError(MP_ERROR_TEXT("invalid endpoint_id"));
    }
    if (umatter_node_has_endpoint_id(self, (uint16_t)endpoint_id)) {
        mp_raise_ValueError(MP_ERROR_TEXT("endpoint_id already exists"));
    }
    {
        int rc = umatter_core_add_endpoint(self->handle, (uint16_t)endpoint_id, (uint32_t)args[ARG_device_type].u_int);
        if (rc == UMATTER_CORE_ERR_EXISTS) {
            mp_raise_ValueError(MP_ERROR_TEXT("endpoint_id already exists"));
        }
        if (rc < 0) {
            umatter_raise_from_rc(rc);
        }
    }

    endpoint = mp_obj_malloc(umatter_endpoint_obj_t, &umatter_endpoint_type);
    endpoint->node_obj = MP_OBJ_FROM_PTR(self);
    endpoint->endpoint_id = (uint16_t)endpoint_id;
    endpoint->device_type = (uint32_t)args[ARG_device_type].u_int;
    endpoint->cluster_count = 0;
    memset(endpoint->cluster_ids, 0, sizeof(endpoint->cluster_ids));

    self->endpoint_ids[self->endpoint_count] = (uint16_t)endpoint_id;
    self->endpoint_count += 1;
    return MP_OBJ_FROM_PTR(endpoint);
}
static MP_DEFINE_CONST_FUN_OBJ_KW(umatter_node_add_endpoint_obj, 1, umatter_node_add_endpoint);

static mp_obj_t umatter_node_endpoint_count(mp_obj_t self_in) {
    umatter_node_obj_t *self = MP_OBJ_TO_PTR(self_in);
    int rc = umatter_core_endpoint_count(self->handle);
    if (rc < 0) {
        umatter_raise_from_rc(rc);
    }
    return mp_obj_new_int_from_uint(rc);
}
static MP_DEFINE_CONST_FUN_OBJ_1(umatter_node_endpoint_count_obj, umatter_node_endpoint_count);

static mp_obj_t umatter_endpoint_add_cluster(mp_obj_t self_in, mp_obj_t cluster_id_in) {
    umatter_endpoint_obj_t *self = MP_OBJ_TO_PTR(self_in);
    umatter_node_obj_t *node = MP_OBJ_TO_PTR(self->node_obj);
    mp_int_t cluster_id = mp_obj_get_int(cluster_id_in);

    umatter_raise_if_closed_node(node->handle);
    if (cluster_id <= 0 || (mp_uint_t)cluster_id > UINT32_MAX) {
        mp_raise_ValueError(MP_ERROR_TEXT("invalid cluster_id"));
    }
    if (self->cluster_count >= UMATTER_CLUSTERS_MAX_PER_ENDPOINT) {
        mp_raise_msg(&mp_type_MemoryError, MP_ERROR_TEXT("no free cluster slots"));
    }
    if (umatter_endpoint_has_cluster_id(self, (uint32_t)cluster_id)) {
        mp_raise_ValueError(MP_ERROR_TEXT("cluster already exists"));
    }
    {
        int rc = umatter_core_add_cluster(node->handle, self->endpoint_id, (uint32_t)cluster_id);
        if (rc == UMATTER_CORE_ERR_EXISTS) {
            mp_raise_ValueError(MP_ERROR_TEXT("cluster already exists"));
        }
        if (rc < 0) {
            umatter_raise_from_rc(rc);
        }
    }

    self->cluster_ids[self->cluster_count] = (uint32_t)cluster_id;
    self->cluster_count += 1;
    return mp_const_none;
}
static MP_DEFINE_CONST_FUN_OBJ_2(umatter_endpoint_add_cluster_obj, umatter_endpoint_add_cluster);

static mp_obj_t umatter_endpoint_cluster_count(mp_obj_t self_in) {
    umatter_endpoint_obj_t *self = MP_OBJ_TO_PTR(self_in);
    umatter_node_obj_t *node = MP_OBJ_TO_PTR(self->node_obj);
    int rc = umatter_core_cluster_count(node->handle, self->endpoint_id);
    if (rc < 0) {
        umatter_raise_from_rc(rc);
    }
    return mp_obj_new_int_from_uint(rc);
}
static MP_DEFINE_CONST_FUN_OBJ_1(umatter_endpoint_cluster_count_obj, umatter_endpoint_cluster_count);

static mp_obj_t umatter_light(size_t n_args, const mp_obj_t *all_args, mp_map_t *kw_args) {
    enum { ARG_name, ARG_vendor_id, ARG_product_id, ARG_endpoint_id, ARG_with_level_control, ARG_passcode, ARG_discriminator, ARG_transport };
    static const mp_arg_t allowed_args[] = {
        { MP_QSTR_name, MP_ARG_KW_ONLY | MP_ARG_OBJ, {.u_obj = MP_OBJ_NEW_QSTR(MP_QSTR_uMatter_Light)} },
        { MP_QSTR_vendor_id, MP_ARG_KW_ONLY | MP_ARG_INT, {.u_int = 0xFFF1} },
        { MP_QSTR_product_id, MP_ARG_KW_ONLY | MP_ARG_INT, {.u_int = 0x8101} },
        { MP_QSTR_endpoint_id, MP_ARG_KW_ONLY | MP_ARG_INT, {.u_int = 1} },
        { MP_QSTR_with_level_control, MP_ARG_KW_ONLY | MP_ARG_BOOL, {.u_bool = true} },
        { MP_QSTR_passcode, MP_ARG_KW_ONLY | MP_ARG_INT, {.u_int = UMATTER_DEFAULT_PASSCODE} },
        { MP_QSTR_discriminator, MP_ARG_KW_ONLY | MP_ARG_INT, {.u_int = UMATTER_DEFAULT_DISCRIMINATOR} },
        { MP_QSTR_transport, MP_ARG_KW_ONLY | MP_ARG_OBJ, {.u_obj = MP_OBJ_NEW_QSTR(MP_QSTR_wifi)} },
    };
    mp_arg_val_t args[MP_ARRAY_SIZE(allowed_args)];
    const char *name = NULL;
    mp_obj_t node_obj = mp_const_none;
    umatter_node_obj_t *node = NULL;
    int endpoint_id = 0;
    int rc = UMATTER_CORE_OK;
    int transport_mode = UMATTER_CORE_TRANSPORT_WIFI;

    mp_arg_parse_all(n_args, all_args, kw_args, MP_ARRAY_SIZE(allowed_args), allowed_args, args);
    name = mp_obj_str_get_str(args[ARG_name].u_obj);
    transport_mode = umatter_parse_transport_mode(args[ARG_transport].u_obj);
    if (args[ARG_passcode].u_int < UMATTER_MIN_PASSCODE || (mp_uint_t)args[ARG_passcode].u_int > UMATTER_MAX_PASSCODE) {
        mp_raise_ValueError(MP_ERROR_TEXT("invalid passcode"));
    }
    if (args[ARG_discriminator].u_int < 0 || args[ARG_discriminator].u_int > 0x0FFF) {
        mp_raise_ValueError(MP_ERROR_TEXT("invalid discriminator"));
    }
    node_obj = umatter_node_new_from_values(&umatter_node_type, (uint16_t)args[ARG_vendor_id].u_int, (uint16_t)args[ARG_product_id].u_int, name);
    node = MP_OBJ_TO_PTR(node_obj);

    endpoint_id = args[ARG_endpoint_id].u_int;
    if (endpoint_id <= 0 || endpoint_id > 0xFFFF) {
        if (node->handle > 0) {
            (void)umatter_core_destroy(node->handle);
            node->handle = 0;
        }
        mp_raise_ValueError(MP_ERROR_TEXT("invalid endpoint_id"));
    }

    rc = umatter_core_add_endpoint(node->handle, (uint16_t)endpoint_id, UMATTER_DEVICE_TYPE_ON_OFF_LIGHT);
    if (rc < 0) {
        goto fail;
    }

    rc = umatter_core_add_cluster(node->handle, (uint16_t)endpoint_id, UMATTER_CLUSTER_ON_OFF);
    if (rc < 0) {
        goto fail;
    }

    if (args[ARG_with_level_control].u_bool) {
        rc = umatter_core_add_cluster(node->handle, (uint16_t)endpoint_id, UMATTER_CLUSTER_LEVEL_CONTROL);
        if (rc < 0) {
            goto fail;
        }
    }

    rc = umatter_core_set_commissioning(node->handle, (uint16_t)args[ARG_discriminator].u_int, (uint32_t)args[ARG_passcode].u_int);
    if (rc < 0) {
        goto fail;
    }

    rc = umatter_core_set_transport(node->handle, (uint8_t)transport_mode);
    if (rc < 0) {
        goto fail;
    }

    node->endpoint_ids[node->endpoint_count] = (uint16_t)endpoint_id;
    node->endpoint_count += 1;
    return node_obj;

fail:
    if (node != NULL && node->handle > 0) {
        (void)umatter_core_destroy(node->handle);
        node->handle = 0;
        node->endpoint_count = 0;
        memset(node->endpoint_ids, 0, sizeof(node->endpoint_ids));
    }
    umatter_raise_from_rc(rc);
    return mp_const_none;
}
static MP_DEFINE_CONST_FUN_OBJ_KW(umatter_light_obj, 0, umatter_light);

static const mp_rom_map_elem_t umatter_endpoint_locals_dict_table[] = {
    { MP_ROM_QSTR(MP_QSTR_add_cluster), MP_ROM_PTR(&umatter_endpoint_add_cluster_obj) },
    { MP_ROM_QSTR(MP_QSTR_cluster_count), MP_ROM_PTR(&umatter_endpoint_cluster_count_obj) },
};
static MP_DEFINE_CONST_DICT(umatter_endpoint_locals_dict, umatter_endpoint_locals_dict_table);

MP_DEFINE_CONST_OBJ_TYPE(
    umatter_endpoint_type,
    MP_QSTR_Endpoint,
    MP_TYPE_FLAG_NONE,
    make_new, umatter_endpoint_make_new,
    locals_dict, &umatter_endpoint_locals_dict
    );

static const mp_rom_map_elem_t umatter_node_locals_dict_table[] = {
    { MP_ROM_QSTR(MP_QSTR_start), MP_ROM_PTR(&umatter_node_start_obj) },
    { MP_ROM_QSTR(MP_QSTR_stop), MP_ROM_PTR(&umatter_node_stop_obj) },
    { MP_ROM_QSTR(MP_QSTR_close), MP_ROM_PTR(&umatter_node_close_obj) },
    { MP_ROM_QSTR(MP_QSTR_is_started), MP_ROM_PTR(&umatter_node_is_started_obj) },
    { MP_ROM_QSTR(MP_QSTR_set_commissioning), MP_ROM_PTR(&umatter_node_set_commissioning_obj) },
    { MP_ROM_QSTR(MP_QSTR_commissioning), MP_ROM_PTR(&umatter_node_commissioning_obj) },
    { MP_ROM_QSTR(MP_QSTR_set_transport), MP_ROM_PTR(&umatter_node_set_transport_obj) },
    { MP_ROM_QSTR(MP_QSTR_transport), MP_ROM_PTR(&umatter_node_transport_obj) },
    { MP_ROM_QSTR(MP_QSTR_commissioning_ready), MP_ROM_PTR(&umatter_node_commissioning_ready_obj) },
    { MP_ROM_QSTR(MP_QSTR_commissioning_ready_reason), MP_ROM_PTR(&umatter_node_commissioning_ready_reason_obj) },
    { MP_ROM_QSTR(MP_QSTR_set_network_advertising), MP_ROM_PTR(&umatter_node_set_network_advertising_obj) },
    { MP_ROM_QSTR(MP_QSTR_network_advertising), MP_ROM_PTR(&umatter_node_network_advertising_obj) },
    { MP_ROM_QSTR(MP_QSTR_commissioning_diagnostics), MP_ROM_PTR(&umatter_node_commissioning_diagnostics_obj) },
    { MP_ROM_QSTR(MP_QSTR_manual_code), MP_ROM_PTR(&umatter_node_manual_code_obj) },
    { MP_ROM_QSTR(MP_QSTR_qr_code), MP_ROM_PTR(&umatter_node_qr_code_obj) },
    { MP_ROM_QSTR(MP_QSTR_add_endpoint), MP_ROM_PTR(&umatter_node_add_endpoint_obj) },
    { MP_ROM_QSTR(MP_QSTR_endpoint_count), MP_ROM_PTR(&umatter_node_endpoint_count_obj) },
};
static MP_DEFINE_CONST_DICT(umatter_node_locals_dict, umatter_node_locals_dict_table);

MP_DEFINE_CONST_OBJ_TYPE(
    umatter_node_type,
    MP_QSTR_Node,
    MP_TYPE_FLAG_NONE,
    make_new, umatter_node_make_new,
    locals_dict, &umatter_node_locals_dict
    );

static const mp_rom_map_elem_t umatter_module_globals_table[] = {
    { MP_ROM_QSTR(MP_QSTR___name__), MP_ROM_QSTR(MP_QSTR_umatter) },
    { MP_ROM_QSTR(MP_QSTR___version__), MP_ROM_QSTR(MP_QSTR_stub) },
    { MP_ROM_QSTR(MP_QSTR_is_stub), MP_ROM_PTR(&umatter_is_stub_obj) },
    { MP_ROM_QSTR(MP_QSTR_Node), MP_ROM_PTR(&umatter_node_type) },
    { MP_ROM_QSTR(MP_QSTR_Endpoint), MP_ROM_PTR(&umatter_endpoint_type) },
    { MP_ROM_QSTR(MP_QSTR_Light), MP_ROM_PTR(&umatter_light_obj) },
    { MP_ROM_QSTR(MP_QSTR_DEVICE_TYPE_ON_OFF_LIGHT), MP_ROM_INT(UMATTER_DEVICE_TYPE_ON_OFF_LIGHT) },
    { MP_ROM_QSTR(MP_QSTR_CLUSTER_ON_OFF), MP_ROM_INT(UMATTER_CLUSTER_ON_OFF) },
    { MP_ROM_QSTR(MP_QSTR_CLUSTER_LEVEL_CONTROL), MP_ROM_INT(UMATTER_CLUSTER_LEVEL_CONTROL) },
    { MP_ROM_QSTR(MP_QSTR_TRANSPORT_NONE), MP_ROM_INT(UMATTER_CORE_TRANSPORT_NONE) },
    { MP_ROM_QSTR(MP_QSTR_TRANSPORT_WIFI), MP_ROM_INT(UMATTER_CORE_TRANSPORT_WIFI) },
    { MP_ROM_QSTR(MP_QSTR_TRANSPORT_THREAD), MP_ROM_INT(UMATTER_CORE_TRANSPORT_THREAD) },
    { MP_ROM_QSTR(MP_QSTR_TRANSPORT_DUAL), MP_ROM_INT(UMATTER_CORE_TRANSPORT_DUAL) },
    { MP_ROM_QSTR(MP_QSTR_READY_REASON_READY), MP_ROM_INT(UMATTER_CORE_READY_REASON_READY) },
    { MP_ROM_QSTR(MP_QSTR_READY_REASON_TRANSPORT_NOT_CONFIGURED), MP_ROM_INT(UMATTER_CORE_READY_REASON_TRANSPORT_NOT_CONFIGURED) },
    { MP_ROM_QSTR(MP_QSTR_READY_REASON_NO_ENDPOINTS), MP_ROM_INT(UMATTER_CORE_READY_REASON_NO_ENDPOINTS) },
    { MP_ROM_QSTR(MP_QSTR_READY_REASON_NODE_NOT_STARTED), MP_ROM_INT(UMATTER_CORE_READY_REASON_NODE_NOT_STARTED) },
    { MP_ROM_QSTR(MP_QSTR_NETWORK_ADVERTISING_REASON_UNKNOWN), MP_ROM_INT(UMATTER_CORE_NETWORK_ADVERTISING_REASON_UNKNOWN) },
    { MP_ROM_QSTR(MP_QSTR_NETWORK_ADVERTISING_REASON_RUNTIME_NOT_READY), MP_ROM_INT(UMATTER_CORE_NETWORK_ADVERTISING_REASON_RUNTIME_NOT_READY) },
    { MP_ROM_QSTR(MP_QSTR_NETWORK_ADVERTISING_REASON_NOT_INTEGRATED), MP_ROM_INT(UMATTER_CORE_NETWORK_ADVERTISING_REASON_NOT_INTEGRATED) },
    { MP_ROM_QSTR(MP_QSTR_NETWORK_ADVERTISING_REASON_SIGNAL_PRESENT), MP_ROM_INT(UMATTER_CORE_NETWORK_ADVERTISING_REASON_SIGNAL_PRESENT) },
    { MP_ROM_QSTR(MP_QSTR_NETWORK_ADVERTISING_REASON_SIGNAL_LOST), MP_ROM_INT(UMATTER_CORE_NETWORK_ADVERTISING_REASON_SIGNAL_LOST) },
};
static MP_DEFINE_CONST_DICT(umatter_module_globals, umatter_module_globals_table);

const mp_obj_module_t mp_module_umatter = {
    .base = { &mp_type_module },
    .globals = (mp_obj_dict_t *)&umatter_module_globals,
};

MP_REGISTER_MODULE(MP_QSTR_umatter, mp_module_umatter);

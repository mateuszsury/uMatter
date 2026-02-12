#include "py/obj.h"
#include "py/runtime.h"
#include <string.h>

#include "umatter_core.h"

static mp_obj_t mod_umatter_core_create(size_t n_args, const mp_obj_t *args) {
    int handle = 0;
    uint16_t vendor_id = (uint16_t)mp_obj_get_int(args[0]);
    uint16_t product_id = (uint16_t)mp_obj_get_int(args[1]);
    const char *name = mp_obj_str_get_str(args[2]);

    handle = umatter_core_create(vendor_id, product_id, name);
    return mp_obj_new_int(handle);
}
static MP_DEFINE_CONST_FUN_OBJ_VAR_BETWEEN(mod_umatter_core_create_obj, 3, 3, mod_umatter_core_create);

static mp_obj_t mod_umatter_core_start(mp_obj_t handle_in) {
    int rc = umatter_core_start(mp_obj_get_int(handle_in));
    return mp_obj_new_int(rc);
}
static MP_DEFINE_CONST_FUN_OBJ_1(mod_umatter_core_start_obj, mod_umatter_core_start);

static mp_obj_t mod_umatter_core_stop(mp_obj_t handle_in) {
    int rc = umatter_core_stop(mp_obj_get_int(handle_in));
    return mp_obj_new_int(rc);
}
static MP_DEFINE_CONST_FUN_OBJ_1(mod_umatter_core_stop_obj, mod_umatter_core_stop);

static mp_obj_t mod_umatter_core_destroy(mp_obj_t handle_in) {
    int rc = umatter_core_destroy(mp_obj_get_int(handle_in));
    return mp_obj_new_int(rc);
}
static MP_DEFINE_CONST_FUN_OBJ_1(mod_umatter_core_destroy_obj, mod_umatter_core_destroy);

static mp_obj_t mod_umatter_core_is_started(mp_obj_t handle_in) {
    int rc = umatter_core_is_started(mp_obj_get_int(handle_in));
    return mp_obj_new_int(rc);
}
static MP_DEFINE_CONST_FUN_OBJ_1(mod_umatter_core_is_started_obj, mod_umatter_core_is_started);

static mp_obj_t mod_umatter_core_add_endpoint(size_t n_args, const mp_obj_t *args) {
    int rc = umatter_core_add_endpoint(
        mp_obj_get_int(args[0]),
        (uint16_t)mp_obj_get_int(args[1]),
        (uint32_t)mp_obj_get_int(args[2]));
    return mp_obj_new_int(rc);
}
static MP_DEFINE_CONST_FUN_OBJ_VAR_BETWEEN(mod_umatter_core_add_endpoint_obj, 3, 3, mod_umatter_core_add_endpoint);

static mp_obj_t mod_umatter_core_add_cluster(size_t n_args, const mp_obj_t *args) {
    int rc = umatter_core_add_cluster(
        mp_obj_get_int(args[0]),
        (uint16_t)mp_obj_get_int(args[1]),
        (uint32_t)mp_obj_get_int(args[2]));
    return mp_obj_new_int(rc);
}
static MP_DEFINE_CONST_FUN_OBJ_VAR_BETWEEN(mod_umatter_core_add_cluster_obj, 3, 3, mod_umatter_core_add_cluster);

static mp_obj_t mod_umatter_core_endpoint_count(mp_obj_t handle_in) {
    int rc = umatter_core_endpoint_count(mp_obj_get_int(handle_in));
    return mp_obj_new_int(rc);
}
static MP_DEFINE_CONST_FUN_OBJ_1(mod_umatter_core_endpoint_count_obj, mod_umatter_core_endpoint_count);

static mp_obj_t mod_umatter_core_cluster_count(mp_obj_t handle_in, mp_obj_t endpoint_id_in) {
    int rc = umatter_core_cluster_count(mp_obj_get_int(handle_in), (uint16_t)mp_obj_get_int(endpoint_id_in));
    return mp_obj_new_int(rc);
}
static MP_DEFINE_CONST_FUN_OBJ_2(mod_umatter_core_cluster_count_obj, mod_umatter_core_cluster_count);

static mp_obj_t mod_umatter_core_set_commissioning(size_t n_args, const mp_obj_t *args) {
    int rc = umatter_core_set_commissioning(
        mp_obj_get_int(args[0]),
        (uint16_t)mp_obj_get_int(args[1]),
        (uint32_t)mp_obj_get_int(args[2]));
    return mp_obj_new_int(rc);
}
static MP_DEFINE_CONST_FUN_OBJ_VAR_BETWEEN(mod_umatter_core_set_commissioning_obj, 3, 3, mod_umatter_core_set_commissioning);

static mp_obj_t mod_umatter_core_get_commissioning(mp_obj_t handle_in) {
    uint16_t discriminator = 0;
    uint32_t passcode = 0;
    int rc = umatter_core_get_commissioning(mp_obj_get_int(handle_in), &discriminator, &passcode);
    if (rc < 0) {
        return mp_obj_new_int(rc);
    }
    mp_obj_t items[2] = {
        mp_obj_new_int_from_uint(discriminator),
        mp_obj_new_int_from_uint(passcode),
    };
    return mp_obj_new_tuple(2, items);
}
static MP_DEFINE_CONST_FUN_OBJ_1(mod_umatter_core_get_commissioning_obj, mod_umatter_core_get_commissioning);

static mp_obj_t mod_umatter_core_get_manual_code(mp_obj_t handle_in) {
    char code[12];
    int rc = umatter_core_get_manual_code(mp_obj_get_int(handle_in), code, sizeof(code));
    if (rc < 0) {
        return mp_obj_new_int(rc);
    }
    return mp_obj_new_str(code, strlen(code));
}
static MP_DEFINE_CONST_FUN_OBJ_1(mod_umatter_core_get_manual_code_obj, mod_umatter_core_get_manual_code);

static mp_obj_t mod_umatter_core_get_qr_code(mp_obj_t handle_in) {
    char code[32];
    int rc = umatter_core_get_qr_code(mp_obj_get_int(handle_in), code, sizeof(code));
    if (rc < 0) {
        return mp_obj_new_int(rc);
    }
    return mp_obj_new_str(code, strlen(code));
}
static MP_DEFINE_CONST_FUN_OBJ_1(mod_umatter_core_get_qr_code_obj, mod_umatter_core_get_qr_code);

static mp_obj_t mod_umatter_core_set_transport(mp_obj_t handle_in, mp_obj_t transport_mode_in) {
    int rc = umatter_core_set_transport(
        mp_obj_get_int(handle_in),
        (uint8_t)mp_obj_get_int(transport_mode_in));
    return mp_obj_new_int(rc);
}
static MP_DEFINE_CONST_FUN_OBJ_2(mod_umatter_core_set_transport_obj, mod_umatter_core_set_transport);

static mp_obj_t mod_umatter_core_get_transport(mp_obj_t handle_in) {
    uint8_t mode = UMATTER_CORE_TRANSPORT_NONE;
    int rc = umatter_core_get_transport(mp_obj_get_int(handle_in), &mode);
    if (rc < 0) {
        return mp_obj_new_int(rc);
    }
    return mp_obj_new_int_from_uint(mode);
}
static MP_DEFINE_CONST_FUN_OBJ_1(mod_umatter_core_get_transport_obj, mod_umatter_core_get_transport);

static mp_obj_t mod_umatter_core_commissioning_ready(mp_obj_t handle_in) {
    int rc = umatter_core_commissioning_ready(mp_obj_get_int(handle_in));
    return mp_obj_new_int(rc);
}
static MP_DEFINE_CONST_FUN_OBJ_1(mod_umatter_core_commissioning_ready_obj, mod_umatter_core_commissioning_ready);

static mp_obj_t mod_umatter_core_commissioning_ready_reason(mp_obj_t handle_in) {
    int rc = umatter_core_commissioning_ready_reason(mp_obj_get_int(handle_in));
    return mp_obj_new_int(rc);
}
static MP_DEFINE_CONST_FUN_OBJ_1(mod_umatter_core_commissioning_ready_reason_obj, mod_umatter_core_commissioning_ready_reason);

static mp_obj_t mod_umatter_core_set_network_advertising(size_t n_args, const mp_obj_t *args) {
    int handle = mp_obj_get_int(args[0]);
    int advertising = mp_obj_is_true(args[1]) ? 1 : 0;
    uint8_t reason_code = UMATTER_CORE_NETWORK_ADVERTISING_REASON_UNKNOWN;
    if (n_args >= 3) {
        reason_code = (uint8_t)mp_obj_get_int(args[2]);
    }
    int rc = umatter_core_set_network_advertising(handle, advertising, reason_code);
    return mp_obj_new_int(rc);
}
static MP_DEFINE_CONST_FUN_OBJ_VAR_BETWEEN(mod_umatter_core_set_network_advertising_obj, 2, 3, mod_umatter_core_set_network_advertising);

static mp_obj_t mod_umatter_core_get_network_advertising(mp_obj_t handle_in) {
    int advertising = 0;
    uint8_t reason_code = UMATTER_CORE_NETWORK_ADVERTISING_REASON_UNKNOWN;
    int rc = umatter_core_get_network_advertising(mp_obj_get_int(handle_in), &advertising, &reason_code);
    if (rc < 0) {
        return mp_obj_new_int(rc);
    }
    mp_obj_t items[2] = {
        mp_obj_new_bool(advertising != 0),
        mp_obj_new_int_from_uint(reason_code),
    };
    return mp_obj_new_tuple(2, items);
}
static MP_DEFINE_CONST_FUN_OBJ_1(mod_umatter_core_get_network_advertising_obj, mod_umatter_core_get_network_advertising);

static const mp_rom_map_elem_t mod_umatter_core_globals_table[] = {
    { MP_ROM_QSTR(MP_QSTR___name__), MP_ROM_QSTR(MP_QSTR__umatter_core) },
    { MP_ROM_QSTR(MP_QSTR_create), MP_ROM_PTR(&mod_umatter_core_create_obj) },
    { MP_ROM_QSTR(MP_QSTR_start), MP_ROM_PTR(&mod_umatter_core_start_obj) },
    { MP_ROM_QSTR(MP_QSTR_stop), MP_ROM_PTR(&mod_umatter_core_stop_obj) },
    { MP_ROM_QSTR(MP_QSTR_destroy), MP_ROM_PTR(&mod_umatter_core_destroy_obj) },
    { MP_ROM_QSTR(MP_QSTR_is_started), MP_ROM_PTR(&mod_umatter_core_is_started_obj) },
    { MP_ROM_QSTR(MP_QSTR_add_endpoint), MP_ROM_PTR(&mod_umatter_core_add_endpoint_obj) },
    { MP_ROM_QSTR(MP_QSTR_add_cluster), MP_ROM_PTR(&mod_umatter_core_add_cluster_obj) },
    { MP_ROM_QSTR(MP_QSTR_endpoint_count), MP_ROM_PTR(&mod_umatter_core_endpoint_count_obj) },
    { MP_ROM_QSTR(MP_QSTR_cluster_count), MP_ROM_PTR(&mod_umatter_core_cluster_count_obj) },
    { MP_ROM_QSTR(MP_QSTR_set_commissioning), MP_ROM_PTR(&mod_umatter_core_set_commissioning_obj) },
    { MP_ROM_QSTR(MP_QSTR_get_commissioning), MP_ROM_PTR(&mod_umatter_core_get_commissioning_obj) },
    { MP_ROM_QSTR(MP_QSTR_get_manual_code), MP_ROM_PTR(&mod_umatter_core_get_manual_code_obj) },
    { MP_ROM_QSTR(MP_QSTR_get_qr_code), MP_ROM_PTR(&mod_umatter_core_get_qr_code_obj) },
    { MP_ROM_QSTR(MP_QSTR_set_transport), MP_ROM_PTR(&mod_umatter_core_set_transport_obj) },
    { MP_ROM_QSTR(MP_QSTR_get_transport), MP_ROM_PTR(&mod_umatter_core_get_transport_obj) },
    { MP_ROM_QSTR(MP_QSTR_commissioning_ready), MP_ROM_PTR(&mod_umatter_core_commissioning_ready_obj) },
    { MP_ROM_QSTR(MP_QSTR_commissioning_ready_reason), MP_ROM_PTR(&mod_umatter_core_commissioning_ready_reason_obj) },
    { MP_ROM_QSTR(MP_QSTR_set_network_advertising), MP_ROM_PTR(&mod_umatter_core_set_network_advertising_obj) },
    { MP_ROM_QSTR(MP_QSTR_get_network_advertising), MP_ROM_PTR(&mod_umatter_core_get_network_advertising_obj) },
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
    { MP_ROM_QSTR(MP_QSTR_ERR_OK), MP_ROM_INT(UMATTER_CORE_OK) },
    { MP_ROM_QSTR(MP_QSTR_ERR_INVALID_ARG), MP_ROM_INT(UMATTER_CORE_ERR_INVALID_ARG) },
    { MP_ROM_QSTR(MP_QSTR_ERR_NOT_FOUND), MP_ROM_INT(UMATTER_CORE_ERR_NOT_FOUND) },
    { MP_ROM_QSTR(MP_QSTR_ERR_STATE), MP_ROM_INT(UMATTER_CORE_ERR_STATE) },
    { MP_ROM_QSTR(MP_QSTR_ERR_CAPACITY), MP_ROM_INT(UMATTER_CORE_ERR_CAPACITY) },
    { MP_ROM_QSTR(MP_QSTR_ERR_EXISTS), MP_ROM_INT(UMATTER_CORE_ERR_EXISTS) },
};
static MP_DEFINE_CONST_DICT(mod_umatter_core_globals, mod_umatter_core_globals_table);

const mp_obj_module_t mp_module__umatter_core = {
    .base = { &mp_type_module },
    .globals = (mp_obj_dict_t *)&mod_umatter_core_globals,
};

MP_REGISTER_MODULE(MP_QSTR__umatter_core, mp_module__umatter_core);

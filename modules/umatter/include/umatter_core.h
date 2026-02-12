#ifndef UMATTER_CORE_H
#define UMATTER_CORE_H

#include <stddef.h>
#include <stdint.h>

#define UMATTER_CORE_OK (0)
#define UMATTER_CORE_ERR_INVALID_ARG (-1)
#define UMATTER_CORE_ERR_NOT_FOUND (-2)
#define UMATTER_CORE_ERR_STATE (-3)
#define UMATTER_CORE_ERR_CAPACITY (-4)
#define UMATTER_CORE_ERR_EXISTS (-5)

#define UMATTER_CORE_TRANSPORT_NONE (0)
#define UMATTER_CORE_TRANSPORT_WIFI (1)
#define UMATTER_CORE_TRANSPORT_THREAD (2)
#define UMATTER_CORE_TRANSPORT_DUAL (3)

#define UMATTER_CORE_READY_REASON_READY (0)
#define UMATTER_CORE_READY_REASON_TRANSPORT_NOT_CONFIGURED (1)
#define UMATTER_CORE_READY_REASON_NO_ENDPOINTS (2)
#define UMATTER_CORE_READY_REASON_NODE_NOT_STARTED (3)

#define UMATTER_CORE_NETWORK_ADVERTISING_REASON_UNKNOWN (0)
#define UMATTER_CORE_NETWORK_ADVERTISING_REASON_RUNTIME_NOT_READY (1)
#define UMATTER_CORE_NETWORK_ADVERTISING_REASON_NOT_INTEGRATED (2)
#define UMATTER_CORE_NETWORK_ADVERTISING_REASON_SIGNAL_PRESENT (3)
#define UMATTER_CORE_NETWORK_ADVERTISING_REASON_SIGNAL_LOST (4)

int umatter_core_create(uint16_t vendor_id, uint16_t product_id, const char *name);
int umatter_core_start(int handle);
int umatter_core_stop(int handle);
int umatter_core_destroy(int handle);
int umatter_core_is_started(int handle);
int umatter_core_add_endpoint(int handle, uint16_t endpoint_id, uint32_t device_type);
int umatter_core_add_cluster(int handle, uint16_t endpoint_id, uint32_t cluster_id);
int umatter_core_endpoint_count(int handle);
int umatter_core_cluster_count(int handle, uint16_t endpoint_id);
int umatter_core_set_commissioning(int handle, uint16_t discriminator, uint32_t passcode);
int umatter_core_get_commissioning(int handle, uint16_t *discriminator_out, uint32_t *passcode_out);
int umatter_core_get_manual_code(int handle, char *out, size_t out_size);
int umatter_core_get_qr_code(int handle, char *out, size_t out_size);
int umatter_core_set_transport(int handle, uint8_t transport_mode);
int umatter_core_get_transport(int handle, uint8_t *transport_mode_out);
int umatter_core_commissioning_ready(int handle);
int umatter_core_commissioning_ready_reason(int handle);
int umatter_core_set_network_advertising(int handle, int advertising, uint8_t reason_code);
int umatter_core_get_network_advertising(int handle, int *advertising_out, uint8_t *reason_code_out);

#endif

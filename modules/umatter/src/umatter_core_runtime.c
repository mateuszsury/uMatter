#include <stdbool.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>

#include "umatter_core.h"

#if defined(ESP_PLATFORM)
#include "mdns.h"
#include "esp_err.h"
#endif

#define UMATTER_CORE_MAX_NODES (4)
#define UMATTER_CORE_NAME_MAX (32)
#define UMATTER_CORE_MAX_ENDPOINTS_PER_NODE (8)
#define UMATTER_CORE_MAX_CLUSTERS_PER_ENDPOINT (16)
#define UMATTER_CORE_DEFAULT_DISCRIMINATOR (3840)
#define UMATTER_CORE_DEFAULT_PASSCODE (20202021U)
#define UMATTER_CORE_MIN_PASSCODE (1U)
#define UMATTER_CORE_MAX_PASSCODE (99999998U)
#define UMATTER_CORE_MANUAL_CODE_LEN (11U)
#define UMATTER_CORE_MANUAL_CODE_BUFSIZE (UMATTER_CORE_MANUAL_CODE_LEN + 1U)
#define UMATTER_CORE_QR_CODE_BUFSIZE (32U)

typedef struct {
    bool in_use;
    uint16_t endpoint_id;
    uint32_t device_type;
    uint16_t cluster_count;
    uint32_t cluster_ids[UMATTER_CORE_MAX_CLUSTERS_PER_ENDPOINT];
} umatter_core_endpoint_t;

typedef struct {
    bool in_use;
    bool started;
    uint16_t vendor_id;
    uint16_t product_id;
    uint8_t transport_mode;
    bool network_advertising;
    uint8_t network_advertising_reason;
    bool network_advertising_manual_override;
    bool network_advertising_mdns_published;
    int network_advertising_mdns_last_error;
    uint16_t discriminator;
    uint32_t passcode;
    char name[UMATTER_CORE_NAME_MAX + 1];
    uint16_t endpoint_count;
    umatter_core_endpoint_t endpoints[UMATTER_CORE_MAX_ENDPOINTS_PER_NODE];
} umatter_core_node_t;

static umatter_core_node_t g_nodes[UMATTER_CORE_MAX_NODES];

#if defined(ESP_PLATFORM)
static bool g_umatter_mdns_initialized = false;
static bool g_umatter_commissionable_registered = false;
static int g_umatter_commissionable_owner_handle = 0;
#endif

static int umatter_core_slot_from_handle(int handle) {
    int slot = handle - 1;
    if (slot < 0 || slot >= UMATTER_CORE_MAX_NODES) {
        return -1;
    }
    return slot;
}

static umatter_core_node_t *umatter_core_node_from_handle(int handle) {
    int slot = umatter_core_slot_from_handle(handle);
    if (slot < 0 || !g_nodes[slot].in_use) {
        return NULL;
    }
    return &g_nodes[slot];
}

static umatter_core_endpoint_t *umatter_core_find_endpoint(umatter_core_node_t *node, uint16_t endpoint_id) {
    for (size_t i = 0; i < UMATTER_CORE_MAX_ENDPOINTS_PER_NODE; ++i) {
        umatter_core_endpoint_t *endpoint = &node->endpoints[i];
        if (endpoint->in_use && endpoint->endpoint_id == endpoint_id) {
            return endpoint;
        }
    }
    return NULL;
}

static int umatter_core_commissioning_ready_reason_from_node(const umatter_core_node_t *node) {
    if (node->transport_mode == UMATTER_CORE_TRANSPORT_NONE) {
        return UMATTER_CORE_READY_REASON_TRANSPORT_NOT_CONFIGURED;
    }
    if (node->endpoint_count == 0) {
        return UMATTER_CORE_READY_REASON_NO_ENDPOINTS;
    }
    if (!node->started) {
        return UMATTER_CORE_READY_REASON_NODE_NOT_STARTED;
    }
    return UMATTER_CORE_READY_REASON_READY;
}

static bool umatter_core_network_advertising_reason_valid(uint8_t reason_code) {
    switch (reason_code) {
        case UMATTER_CORE_NETWORK_ADVERTISING_REASON_UNKNOWN:
        case UMATTER_CORE_NETWORK_ADVERTISING_REASON_RUNTIME_NOT_READY:
        case UMATTER_CORE_NETWORK_ADVERTISING_REASON_NOT_INTEGRATED:
        case UMATTER_CORE_NETWORK_ADVERTISING_REASON_SIGNAL_PRESENT:
        case UMATTER_CORE_NETWORK_ADVERTISING_REASON_SIGNAL_LOST:
            return true;
        default:
            return false;
    }
}

#if defined(ESP_PLATFORM)
static void umatter_core_unpublish_commissionable(int handle) {
    if (!g_umatter_commissionable_registered || g_umatter_commissionable_owner_handle != handle) {
        return;
    }
    (void)mdns_service_remove("_matterc", "_udp");
    g_umatter_commissionable_registered = false;
    g_umatter_commissionable_owner_handle = 0;
}

static bool umatter_core_publish_commissionable(const umatter_core_node_t *node, int handle, int *mdns_error_out) {
    mdns_txt_item_t txt[7];
    char long_subtype[10];
    char short_subtype[8];
    esp_err_t err = ESP_FAIL;
    char discriminator_str[8];
    char vendor_product_str[16];

    if (mdns_error_out != NULL) {
        *mdns_error_out = 0;
    }

    if (g_umatter_commissionable_registered) {
        if (g_umatter_commissionable_owner_handle == handle) {
            return true;
        }
        if (mdns_error_out != NULL) {
            *mdns_error_out = ESP_ERR_INVALID_STATE;
        }
        return false;
    }

    if (!g_umatter_mdns_initialized) {
        err = mdns_init();
        if (err != ESP_OK) {
            if (mdns_error_out != NULL) {
                *mdns_error_out = (int)err;
            }
            return false;
        }
        g_umatter_mdns_initialized = true;
    }

    (void)snprintf(discriminator_str, sizeof(discriminator_str), "%u", (unsigned)node->discriminator);
    (void)snprintf(vendor_product_str, sizeof(vendor_product_str), "%u+%u", (unsigned)node->vendor_id, (unsigned)node->product_id);
    (void)mdns_hostname_set("umatter-node");
    (void)mdns_instance_name_set(node->name);

    txt[0].key = "D";
    txt[0].value = discriminator_str;
    txt[1].key = "VP";
    txt[1].value = vendor_product_str;
    txt[2].key = "CM";
    txt[2].value = "1";
    txt[3].key = "DT";
    txt[3].value = "256";
    txt[4].key = "DN";
    txt[4].value = node->name;
    txt[5].key = "PH";
    txt[5].value = "33";
    txt[6].key = "PI";
    txt[6].value = "Use chip-tool";

    err = mdns_service_add(node->name, "_matterc", "_udp", 5540, txt, sizeof(txt) / sizeof(txt[0]));
    if (err != ESP_OK) {
        if (mdns_error_out != NULL) {
            *mdns_error_out = (int)err;
        }
        return false;
    }

    (void)snprintf(long_subtype, sizeof(long_subtype), "_L%04u", (unsigned)node->discriminator);
    err = mdns_service_subtype_add_for_host(node->name, "_matterc", "_udp", NULL, long_subtype);
    if (err != ESP_OK) {
        (void)mdns_service_remove("_matterc", "_udp");
        if (mdns_error_out != NULL) {
            *mdns_error_out = (int)err;
        }
        return false;
    }

    (void)snprintf(short_subtype, sizeof(short_subtype), "_S%u", (unsigned)(node->discriminator & 0x000F));
    err = mdns_service_subtype_add_for_host(node->name, "_matterc", "_udp", NULL, short_subtype);
    if (err != ESP_OK) {
        (void)mdns_service_remove("_matterc", "_udp");
        if (mdns_error_out != NULL) {
            *mdns_error_out = (int)err;
        }
        return false;
    }

    g_umatter_commissionable_registered = true;
    g_umatter_commissionable_owner_handle = handle;
    return true;
}
#else
static void umatter_core_unpublish_commissionable(int handle) {
    (void)handle;
}

static bool umatter_core_publish_commissionable(const umatter_core_node_t *node, int handle, int *mdns_error_out) {
    (void)node;
    (void)handle;
    if (mdns_error_out != NULL) {
        *mdns_error_out = UMATTER_CORE_ERR_NOT_FOUND;
    }
    return false;
}
#endif

static void umatter_core_reconcile_network_advertising(umatter_core_node_t *node, int handle) {
    int mdns_error = 0;
    int ready_reason = umatter_core_commissioning_ready_reason_from_node(node);
    if (ready_reason != UMATTER_CORE_READY_REASON_READY) {
        umatter_core_unpublish_commissionable(handle);
        node->network_advertising = false;
        node->network_advertising_reason = UMATTER_CORE_NETWORK_ADVERTISING_REASON_RUNTIME_NOT_READY;
        node->network_advertising_manual_override = false;
        node->network_advertising_mdns_published = false;
        return;
    }

    if (node->network_advertising) {
        node->network_advertising_reason = UMATTER_CORE_NETWORK_ADVERTISING_REASON_SIGNAL_PRESENT;
        return;
    }

    if (node->network_advertising_reason == UMATTER_CORE_NETWORK_ADVERTISING_REASON_RUNTIME_NOT_READY ||
        node->network_advertising_reason == UMATTER_CORE_NETWORK_ADVERTISING_REASON_UNKNOWN ||
        node->network_advertising_reason == UMATTER_CORE_NETWORK_ADVERTISING_REASON_NOT_INTEGRATED) {
        node->network_advertising_manual_override = false;
        if (umatter_core_publish_commissionable(node, handle, &mdns_error)) {
            node->network_advertising = true;
            node->network_advertising_reason = UMATTER_CORE_NETWORK_ADVERTISING_REASON_SIGNAL_PRESENT;
            node->network_advertising_mdns_published = true;
            node->network_advertising_mdns_last_error = 0;
        } else {
            node->network_advertising_reason = UMATTER_CORE_NETWORK_ADVERTISING_REASON_NOT_INTEGRATED;
            node->network_advertising_mdns_published = false;
            node->network_advertising_mdns_last_error = mdns_error;
        }
    }
}

int umatter_core_create(uint16_t vendor_id, uint16_t product_id, const char *name) {
    size_t len = 0;
    int slot = 0;

    if (vendor_id == 0 || product_id == 0 || name == NULL) {
        return UMATTER_CORE_ERR_INVALID_ARG;
    }

    len = strlen(name);
    if (len == 0 || len > UMATTER_CORE_NAME_MAX) {
        return UMATTER_CORE_ERR_INVALID_ARG;
    }

    for (slot = 0; slot < UMATTER_CORE_MAX_NODES; ++slot) {
        if (!g_nodes[slot].in_use) {
            g_nodes[slot].in_use = true;
            g_nodes[slot].started = false;
            g_nodes[slot].vendor_id = vendor_id;
            g_nodes[slot].product_id = product_id;
            g_nodes[slot].transport_mode = UMATTER_CORE_TRANSPORT_NONE;
            g_nodes[slot].network_advertising = false;
            g_nodes[slot].network_advertising_reason = UMATTER_CORE_NETWORK_ADVERTISING_REASON_RUNTIME_NOT_READY;
            g_nodes[slot].network_advertising_manual_override = false;
            g_nodes[slot].network_advertising_mdns_published = false;
            g_nodes[slot].network_advertising_mdns_last_error = 0;
            g_nodes[slot].discriminator = UMATTER_CORE_DEFAULT_DISCRIMINATOR;
            g_nodes[slot].passcode = UMATTER_CORE_DEFAULT_PASSCODE;
            memcpy(g_nodes[slot].name, name, len);
            g_nodes[slot].name[len] = '\0';
            return slot + 1;
        }
    }

    return UMATTER_CORE_ERR_CAPACITY;
}

int umatter_core_start(int handle) {
    int slot = umatter_core_slot_from_handle(handle);
    if (slot < 0 || !g_nodes[slot].in_use) {
        return UMATTER_CORE_ERR_NOT_FOUND;
    }
    if (g_nodes[slot].started) {
        return UMATTER_CORE_ERR_STATE;
    }
    g_nodes[slot].started = true;
    umatter_core_reconcile_network_advertising(&g_nodes[slot], handle);
    return UMATTER_CORE_OK;
}

int umatter_core_stop(int handle) {
    int slot = umatter_core_slot_from_handle(handle);
    if (slot < 0 || !g_nodes[slot].in_use) {
        return UMATTER_CORE_ERR_NOT_FOUND;
    }
    if (!g_nodes[slot].started) {
        return UMATTER_CORE_ERR_STATE;
    }
    g_nodes[slot].started = false;
    umatter_core_reconcile_network_advertising(&g_nodes[slot], handle);
    return UMATTER_CORE_OK;
}

int umatter_core_destroy(int handle) {
    int slot = umatter_core_slot_from_handle(handle);
    if (slot < 0 || !g_nodes[slot].in_use) {
        return UMATTER_CORE_ERR_NOT_FOUND;
    }
    umatter_core_unpublish_commissionable(handle);
    memset(&g_nodes[slot], 0, sizeof(g_nodes[slot]));
    return UMATTER_CORE_OK;
}

int umatter_core_is_started(int handle) {
    int slot = umatter_core_slot_from_handle(handle);
    if (slot < 0 || !g_nodes[slot].in_use) {
        return UMATTER_CORE_ERR_NOT_FOUND;
    }
    return g_nodes[slot].started ? 1 : 0;
}

int umatter_core_add_endpoint(int handle, uint16_t endpoint_id, uint32_t device_type) {
    umatter_core_node_t *node = umatter_core_node_from_handle(handle);
    if (node == NULL) {
        return UMATTER_CORE_ERR_NOT_FOUND;
    }
    if (endpoint_id == 0 || device_type == 0) {
        return UMATTER_CORE_ERR_INVALID_ARG;
    }
    if (node->endpoint_count >= UMATTER_CORE_MAX_ENDPOINTS_PER_NODE) {
        return UMATTER_CORE_ERR_CAPACITY;
    }
    if (umatter_core_find_endpoint(node, endpoint_id) != NULL) {
        return UMATTER_CORE_ERR_EXISTS;
    }

    for (size_t i = 0; i < UMATTER_CORE_MAX_ENDPOINTS_PER_NODE; ++i) {
        umatter_core_endpoint_t *endpoint = &node->endpoints[i];
        if (!endpoint->in_use) {
            endpoint->in_use = true;
            endpoint->endpoint_id = endpoint_id;
            endpoint->device_type = device_type;
            endpoint->cluster_count = 0;
            memset(endpoint->cluster_ids, 0, sizeof(endpoint->cluster_ids));
            node->endpoint_count += 1;
            umatter_core_reconcile_network_advertising(node, handle);
            return UMATTER_CORE_OK;
        }
    }

    return UMATTER_CORE_ERR_CAPACITY;
}

int umatter_core_add_cluster(int handle, uint16_t endpoint_id, uint32_t cluster_id) {
    umatter_core_node_t *node = umatter_core_node_from_handle(handle);
    umatter_core_endpoint_t *endpoint = NULL;
    if (node == NULL) {
        return UMATTER_CORE_ERR_NOT_FOUND;
    }
    if (endpoint_id == 0 || cluster_id == 0) {
        return UMATTER_CORE_ERR_INVALID_ARG;
    }

    endpoint = umatter_core_find_endpoint(node, endpoint_id);
    if (endpoint == NULL) {
        return UMATTER_CORE_ERR_NOT_FOUND;
    }
    if (endpoint->cluster_count >= UMATTER_CORE_MAX_CLUSTERS_PER_ENDPOINT) {
        return UMATTER_CORE_ERR_CAPACITY;
    }
    for (size_t i = 0; i < endpoint->cluster_count; ++i) {
        if (endpoint->cluster_ids[i] == cluster_id) {
            return UMATTER_CORE_ERR_EXISTS;
        }
    }

    endpoint->cluster_ids[endpoint->cluster_count] = cluster_id;
    endpoint->cluster_count += 1;
    return UMATTER_CORE_OK;
}

int umatter_core_endpoint_count(int handle) {
    umatter_core_node_t *node = umatter_core_node_from_handle(handle);
    if (node == NULL) {
        return UMATTER_CORE_ERR_NOT_FOUND;
    }
    return node->endpoint_count;
}

int umatter_core_cluster_count(int handle, uint16_t endpoint_id) {
    umatter_core_node_t *node = umatter_core_node_from_handle(handle);
    umatter_core_endpoint_t *endpoint = NULL;
    if (node == NULL) {
        return UMATTER_CORE_ERR_NOT_FOUND;
    }
    if (endpoint_id == 0) {
        return UMATTER_CORE_ERR_INVALID_ARG;
    }

    endpoint = umatter_core_find_endpoint(node, endpoint_id);
    if (endpoint == NULL) {
        return UMATTER_CORE_ERR_NOT_FOUND;
    }
    return endpoint->cluster_count;
}

int umatter_core_set_commissioning(int handle, uint16_t discriminator, uint32_t passcode) {
    umatter_core_node_t *node = umatter_core_node_from_handle(handle);
    if (node == NULL) {
        return UMATTER_CORE_ERR_NOT_FOUND;
    }
    if (discriminator > 0x0FFF) {
        return UMATTER_CORE_ERR_INVALID_ARG;
    }
    if (passcode < UMATTER_CORE_MIN_PASSCODE || passcode > UMATTER_CORE_MAX_PASSCODE) {
        return UMATTER_CORE_ERR_INVALID_ARG;
    }

    node->discriminator = discriminator;
    node->passcode = passcode;
    return UMATTER_CORE_OK;
}

int umatter_core_get_commissioning(int handle, uint16_t *discriminator_out, uint32_t *passcode_out) {
    umatter_core_node_t *node = umatter_core_node_from_handle(handle);
    if (node == NULL) {
        return UMATTER_CORE_ERR_NOT_FOUND;
    }
    if (discriminator_out == NULL || passcode_out == NULL) {
        return UMATTER_CORE_ERR_INVALID_ARG;
    }

    *discriminator_out = node->discriminator;
    *passcode_out = node->passcode;
    return UMATTER_CORE_OK;
}

int umatter_core_get_manual_code(int handle, char *out, size_t out_size) {
    umatter_core_node_t *node = umatter_core_node_from_handle(handle);
    unsigned short_discriminator = 0;
    int len = 0;

    if (node == NULL) {
        return UMATTER_CORE_ERR_NOT_FOUND;
    }
    if (out == NULL || out_size < UMATTER_CORE_MANUAL_CODE_BUFSIZE) {
        return UMATTER_CORE_ERR_INVALID_ARG;
    }

    short_discriminator = (unsigned)(node->discriminator & 0x000F);
    len = snprintf(out, out_size, "%03u%08lu", short_discriminator, (unsigned long)node->passcode);
    if (len != (int)UMATTER_CORE_MANUAL_CODE_LEN) {
        return UMATTER_CORE_ERR_STATE;
    }
    return UMATTER_CORE_OK;
}

int umatter_core_get_qr_code(int handle, char *out, size_t out_size) {
    umatter_core_node_t *node = umatter_core_node_from_handle(handle);
    int len = 0;

    if (node == NULL) {
        return UMATTER_CORE_ERR_NOT_FOUND;
    }
    if (out == NULL || out_size < UMATTER_CORE_QR_CODE_BUFSIZE) {
        return UMATTER_CORE_ERR_INVALID_ARG;
    }

    len = snprintf(out,
                   out_size,
                   "MT:UM%04X%04X%04u%08lu",
                   node->vendor_id,
                   node->product_id,
                   (unsigned)node->discriminator,
                   (unsigned long)node->passcode);
    if (len <= 0 || (size_t)len >= out_size) {
        return UMATTER_CORE_ERR_STATE;
    }
    return UMATTER_CORE_OK;
}

int umatter_core_set_transport(int handle, uint8_t transport_mode) {
    umatter_core_node_t *node = umatter_core_node_from_handle(handle);
    if (node == NULL) {
        return UMATTER_CORE_ERR_NOT_FOUND;
    }
    if (transport_mode > UMATTER_CORE_TRANSPORT_DUAL) {
        return UMATTER_CORE_ERR_INVALID_ARG;
    }
    node->transport_mode = transport_mode;
    umatter_core_reconcile_network_advertising(node, handle);
    return UMATTER_CORE_OK;
}

int umatter_core_get_transport(int handle, uint8_t *transport_mode_out) {
    umatter_core_node_t *node = umatter_core_node_from_handle(handle);
    if (node == NULL) {
        return UMATTER_CORE_ERR_NOT_FOUND;
    }
    if (transport_mode_out == NULL) {
        return UMATTER_CORE_ERR_INVALID_ARG;
    }
    *transport_mode_out = node->transport_mode;
    return UMATTER_CORE_OK;
}

int umatter_core_commissioning_ready(int handle) {
    int ready_reason = umatter_core_commissioning_ready_reason(handle);
    if (ready_reason < 0) {
        return ready_reason;
    }
    return ready_reason == UMATTER_CORE_READY_REASON_READY ? 1 : 0;
}

int umatter_core_commissioning_ready_reason(int handle) {
    umatter_core_node_t *node = umatter_core_node_from_handle(handle);
    if (node == NULL) {
        return UMATTER_CORE_ERR_NOT_FOUND;
    }
    return umatter_core_commissioning_ready_reason_from_node(node);
}

int umatter_core_set_network_advertising(int handle, int advertising, uint8_t reason_code) {
    umatter_core_node_t *node = umatter_core_node_from_handle(handle);
    int ready_reason = 0;
    if (node == NULL) {
        return UMATTER_CORE_ERR_NOT_FOUND;
    }
    if (advertising != 0 && advertising != 1) {
        return UMATTER_CORE_ERR_INVALID_ARG;
    }
    if (!umatter_core_network_advertising_reason_valid(reason_code)) {
        return UMATTER_CORE_ERR_INVALID_ARG;
    }

    ready_reason = umatter_core_commissioning_ready_reason_from_node(node);
    if (ready_reason != UMATTER_CORE_READY_REASON_READY) {
        node->network_advertising = false;
        node->network_advertising_reason = UMATTER_CORE_NETWORK_ADVERTISING_REASON_RUNTIME_NOT_READY;
        node->network_advertising_manual_override = false;
        node->network_advertising_mdns_published = false;
        return advertising ? UMATTER_CORE_ERR_STATE : UMATTER_CORE_OK;
    }

    if (advertising != 0) {
        node->network_advertising = true;
        node->network_advertising_reason = UMATTER_CORE_NETWORK_ADVERTISING_REASON_SIGNAL_PRESENT;
        node->network_advertising_manual_override = true;
        node->network_advertising_mdns_published = false;
        node->network_advertising_mdns_last_error = 0;
        return UMATTER_CORE_OK;
    }

    node->network_advertising = false;
    node->network_advertising_manual_override = false;
    node->network_advertising_mdns_published = false;
    if (reason_code == UMATTER_CORE_NETWORK_ADVERTISING_REASON_SIGNAL_PRESENT ||
        reason_code == UMATTER_CORE_NETWORK_ADVERTISING_REASON_UNKNOWN ||
        reason_code == UMATTER_CORE_NETWORK_ADVERTISING_REASON_RUNTIME_NOT_READY) {
        node->network_advertising_reason = UMATTER_CORE_NETWORK_ADVERTISING_REASON_SIGNAL_LOST;
    } else {
        node->network_advertising_reason = reason_code;
    }
    return UMATTER_CORE_OK;
}

int umatter_core_get_network_advertising(int handle, int *advertising_out, uint8_t *reason_code_out) {
    umatter_core_node_t *node = umatter_core_node_from_handle(handle);
    if (node == NULL) {
        return UMATTER_CORE_ERR_NOT_FOUND;
    }
    if (advertising_out == NULL || reason_code_out == NULL) {
        return UMATTER_CORE_ERR_INVALID_ARG;
    }

    umatter_core_reconcile_network_advertising(node, handle);
    *advertising_out = node->network_advertising ? 1 : 0;
    *reason_code_out = node->network_advertising_reason;
    return UMATTER_CORE_OK;
}

int umatter_core_get_network_advertising_details(int handle,
                                                 int *advertising_out,
                                                 uint8_t *reason_code_out,
                                                 int *mdns_published_out,
                                                 int *mdns_last_error_out,
                                                 int *manual_override_out) {
    umatter_core_node_t *node = umatter_core_node_from_handle(handle);
    if (node == NULL) {
        return UMATTER_CORE_ERR_NOT_FOUND;
    }
    if (advertising_out == NULL || reason_code_out == NULL || mdns_published_out == NULL ||
        mdns_last_error_out == NULL || manual_override_out == NULL) {
        return UMATTER_CORE_ERR_INVALID_ARG;
    }

    umatter_core_reconcile_network_advertising(node, handle);
    *advertising_out = node->network_advertising ? 1 : 0;
    *reason_code_out = node->network_advertising_reason;
    *mdns_published_out = node->network_advertising_mdns_published ? 1 : 0;
    *mdns_last_error_out = node->network_advertising_mdns_last_error;
    *manual_override_out = node->network_advertising_manual_override ? 1 : 0;
    return UMATTER_CORE_OK;
}

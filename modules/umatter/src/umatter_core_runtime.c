#include <stdbool.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>

#include "umatter_core.h"

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
    uint16_t discriminator;
    uint32_t passcode;
    char name[UMATTER_CORE_NAME_MAX + 1];
    uint16_t endpoint_count;
    umatter_core_endpoint_t endpoints[UMATTER_CORE_MAX_ENDPOINTS_PER_NODE];
} umatter_core_node_t;

static umatter_core_node_t g_nodes[UMATTER_CORE_MAX_NODES];

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
    return UMATTER_CORE_OK;
}

int umatter_core_destroy(int handle) {
    int slot = umatter_core_slot_from_handle(handle);
    if (slot < 0 || !g_nodes[slot].in_use) {
        return UMATTER_CORE_ERR_NOT_FOUND;
    }
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
    umatter_core_node_t *node = umatter_core_node_from_handle(handle);
    if (node == NULL) {
        return UMATTER_CORE_ERR_NOT_FOUND;
    }

    if (node->started && node->endpoint_count > 0 && node->transport_mode != UMATTER_CORE_TRANSPORT_NONE) {
        return 1;
    }
    return 0;
}

/* Persistent pointer capability for the isolated CI compositor. No host input. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wayland-client.h>
#include "wlr-virtual-pointer.h"

static struct zwlr_virtual_pointer_manager_v1 *manager;
static void global(void *data, struct wl_registry *registry, uint32_t name,
                   const char *interface, uint32_t version) {
    (void)data;
    (void)version;
    if (strcmp(interface, "zwlr_virtual_pointer_manager_v1") == 0)
        manager = wl_registry_bind(registry, name,
            &zwlr_virtual_pointer_manager_v1_interface, 1);
}
static void removed(void *data, struct wl_registry *registry, uint32_t name) {
    (void)data; (void)registry; (void)name;
}
static const struct wl_registry_listener listener = {global, removed};
int main(void) {
    const char *runtime = getenv("XDG_RUNTIME_DIR");
    if (!runtime || strcmp(runtime, "/tmp/qci") != 0) return 2;
    struct wl_display *display = wl_display_connect(NULL);
    if (!display) return 3;
    struct wl_registry *registry = wl_display_get_registry(display);
    wl_registry_add_listener(registry, &listener, NULL);
    if (wl_display_roundtrip(display) < 0 || !manager) return 4;
    zwlr_virtual_pointer_manager_v1_create_virtual_pointer(manager, NULL);
    if (wl_display_roundtrip(display) < 0) return 5;
    puts("ready");
    fflush(stdout);
    while (wl_display_dispatch(display) >= 0) {}
    wl_display_disconnect(display);
    return 0;
}

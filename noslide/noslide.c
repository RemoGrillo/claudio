// Hides the org_kde_kwin_slide protocol from Ghostty (only Claudio's instance, loaded with LD_PRELOAD by `claudio`):
// without it KWin does not run its own slide animation, and the reveal is drawn by the claudio_reveal effect instead.
// How: it wraps wl_proxy_add_dispatcher (used by zig-wayland) and wl_proxy_add_listener (used by GTK) on wl_registry
// objects and drops the "global" event that announces org_kde_kwin_slide_manager.
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdlib.h>
#include <string.h>
#include <wayland-client-core.h>

struct wl_registry;

#define HIDDEN "org_kde_kwin_slide_manager"

static int hidden(const struct wl_proxy *proxy, uint32_t opcode, const char *interface) {
    return opcode == 0 && interface && strcmp(interface, HIDDEN) == 0 &&
           strcmp(wl_proxy_get_class((struct wl_proxy *)proxy), "wl_registry") == 0;
}

// ---- dispatcher (zig-wayland) ----
struct original { wl_dispatcher_func_t dispatcher; const void *data; };

static int filter(const void *data, void *target, uint32_t opcode, const struct wl_message *msg, union wl_argument *args) {
    const struct original *o = data;
    if (hidden(target, opcode, args[1].s)) return 0;
    return o->dispatcher(o->data, target, opcode, msg, args);
}

int wl_proxy_add_dispatcher(struct wl_proxy *proxy, wl_dispatcher_func_t dispatcher, const void *impl, void *data) {
    static int (*real)(struct wl_proxy *, wl_dispatcher_func_t, const void *, void *);
    if (!real) real = dlsym(RTLD_NEXT, "wl_proxy_add_dispatcher");
    if (strcmp(wl_proxy_get_class(proxy), "wl_registry") != 0) return real(proxy, dispatcher, impl, data);
    struct original *o = malloc(sizeof *o);  // one per registry, never freed: there are only a handful
    o->dispatcher = dispatcher;
    o->data = impl;
    return real(proxy, filter, o, data);
}

// ---- listener (GTK/GDK and others) ----
struct registry_listener {
    void (*global)(void *, struct wl_registry *, uint32_t, const char *, uint32_t);
    void (*global_remove)(void *, struct wl_registry *, uint32_t);
};
// The original listener is looked up by proxy in a small table.
#define MAX_REG 32
static struct { struct wl_proxy *proxy; const struct registry_listener *orig; } table[MAX_REG];

static const struct registry_listener *original_of(struct wl_registry *reg) {
    for (int i = 0; i < MAX_REG; i++) if (table[i].proxy == (struct wl_proxy *)reg) return table[i].orig;
    return NULL;
}
static void global_filtered(void *data, struct wl_registry *reg, uint32_t name, const char *interface, uint32_t version) {
    if (interface && strcmp(interface, HIDDEN) == 0) return;
    const struct registry_listener *l = original_of(reg);
    if (l && l->global) l->global(data, reg, name, interface, version);
}
static void global_remove_pass(void *data, struct wl_registry *reg, uint32_t name) {
    const struct registry_listener *l = original_of(reg);
    if (l && l->global_remove) l->global_remove(data, reg, name);
}
static const struct registry_listener filtered = { global_filtered, global_remove_pass };

int wl_proxy_add_listener(struct wl_proxy *proxy, void (**impl)(void), void *data) {
    static int (*real)(struct wl_proxy *, void (**)(void), void *);
    if (!real) real = dlsym(RTLD_NEXT, "wl_proxy_add_listener");
    if (strcmp(wl_proxy_get_class(proxy), "wl_registry") == 0) {
        for (int i = 0; i < MAX_REG; i++) {
            if (!table[i].proxy || table[i].proxy == proxy) {
                table[i].proxy = proxy;
                table[i].orig = (const struct registry_listener *)impl;
                return real(proxy, (void (**)(void))&filtered, data);
            }
        }
    }
    return real(proxy, impl, data);
}

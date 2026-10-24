# make                      build noslide.so and the shaders
# make install              install system-wide (PREFIX=/usr, DESTDIR for packaging)
# then, as each user:       claudio-setup
PREFIX ?= /usr/local
QSB ?= /usr/lib/qt6/bin/qsb
CFLAGS ?= -O2

EFFECT := share/kwin/effects/claudio_reveal
SHADERS := $(EFFECT)/contents/shaders
GLOW := share/kwin/scripts/claudio-glow
FRAGS := $(foreach s,glitch decrypt scan,$(SHADERS)/$(s).frag $(SHADERS)/$(s)_core.frag)
BIN := $(wildcard bin/claudio*)
DATA := $(DESTDIR)$(PREFIX)/share

all: noslide/noslide.so $(FRAGS) $(GLOW)/contents/ui/glow.frag.qsb

noslide/noslide.so: noslide/noslide.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -Wall -shared -fPIC $(LDFLAGS) -o $@ $< $$(pkg-config --cflags --libs wayland-client) -ldl

# every reveal shader is written once (*.glsl) and wrapped for KWin's legacy and core (GLSL 140) pipelines
$(SHADERS)/%_core.frag: $(SHADERS)/%.glsl
	{ echo '#version 140'; echo '#include "colormanagement.glsl"'; echo 'uniform sampler2D sampler;'; \
	  echo 'in vec2 texcoord0;'; echo 'out vec4 fragColor;'; echo '#define texture2D texture'; \
	  echo '#define OUT(c) fragColor = nitsToDestinationEncoding(sourceEncodingToNitsInDestinationColorspace(c))'; \
	  cat $<; } > $@

$(SHADERS)/%.frag: $(SHADERS)/%.glsl
	{ echo '#include "colormanagement.glsl"'; echo 'uniform sampler2D sampler;'; echo 'varying vec2 texcoord0;'; \
	  echo '#define OUT(c) gl_FragColor = nitsToDestinationEncoding(sourceEncodingToNitsInDestinationColorspace(c))'; \
	  cat $<; } > $@

$(GLOW)/contents/ui/glow.frag.qsb: $(GLOW)/contents/ui/glow.frag
	$(QSB) --glsl "100 es,120,150" --hlsl 50 --msl 12 -o $@ $<

install: all
	install -Dm755 $(BIN) -t $(DESTDIR)$(PREFIX)/bin
	install -Dm755 noslide/noslide.so -t $(DESTDIR)$(PREFIX)/lib/claudio
	install -Dm644 share/claudio/colors.conf -t $(DATA)/claudio
	install -Dm644 share/claudio/ghostty/claudio.conf share/claudio/ghostty/claudio.css -t $(DATA)/claudio/ghostty
	install -Dm644 share/applications/io.github.remogrillo.claudio.desktop -t $(DATA)/applications
	install -Dm644 share/icons/hicolor/scalable/apps/io.github.remogrillo.claudio.svg -t $(DATA)/icons/hicolor/scalable/apps
	install -Dm644 $(EFFECT)/metadata.json -t $(DATA)/kwin/effects/claudio_reveal
	install -Dm644 $(EFFECT)/contents/code/main.js -t $(DATA)/kwin/effects/claudio_reveal/contents/code
	install -Dm644 $(EFFECT)/contents/config/main.xml -t $(DATA)/kwin/effects/claudio_reveal/contents/config
	install -Dm644 $(EFFECT)/contents/ui/config.ui -t $(DATA)/kwin/effects/claudio_reveal/contents/ui
	install -Dm644 $(FRAGS) -t $(DATA)/kwin/effects/claudio_reveal/contents/shaders
	install -Dm644 $(GLOW)/metadata.json -t $(DATA)/kwin/scripts/claudio-glow
	install -Dm644 $(GLOW)/contents/ui/*.qml $(GLOW)/contents/ui/glow.frag.qsb -t $(DATA)/kwin/scripts/claudio-glow/contents/ui
	install -Dm644 README.md -t $(DATA)/doc/claudio

uninstall:
	rm -f $(addprefix $(DESTDIR)$(PREFIX)/,$(BIN)) $(DATA)/applications/io.github.remogrillo.claudio.desktop \
	      $(DATA)/icons/hicolor/scalable/apps/io.github.remogrillo.claudio.svg
	rm -rf $(DESTDIR)$(PREFIX)/lib/claudio $(DATA)/claudio $(DATA)/doc/claudio \
	       $(DATA)/kwin/effects/claudio_reveal $(DATA)/kwin/scripts/claudio-glow

check:
	bash -n bin/claudio bin/claudio-tab bin/claudio-toggle bin/claudio-effect
	python3 -m py_compile bin/claudio-tray bin/claudio-hook bin/claudio-statusline bin/claudio-copilot-key bin/claudio-setup

clean:
	rm -f noslide/noslide.so $(FRAGS) $(GLOW)/contents/ui/glow.frag.qsb

.PHONY: all install uninstall check clean

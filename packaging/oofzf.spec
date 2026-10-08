Name:           oofzf
Version:        0.2.0
Release:        1%{?dist}
Summary:        Sovereign interactive fuzzy finder and candidate ranker
License:        ASL 2.0
URL:            https://github.com/openOODA-tools/oofzf
Source0:        oofzf-linux-x86_64
Source1:        uninstall.sh
BuildArch:      x86_64
Requires:       glibc

%description
oofzf is a sovereign, capability-bounded interactive fuzzy finder and candidate ranker
written in pure openOODA, featuring progressive boundary scoring, oote themes,
CLI filter mode, and an MCP stdio server.

%install
mkdir -p %{buildroot}/usr/bin
install -m 0755 %{SOURCE0} %{buildroot}/usr/bin/oofzf
install -m 0755 %{SOURCE1} %{buildroot}/usr/bin/oofzf-uninstall

%files
/usr/bin/oofzf
/usr/bin/oofzf-uninstall

%changelog
* Wed Oct 07 2026 openOODA-tools <ops@openooda.org> - 0.2.0-1
- Elevate to S+ tier: streaming JSON-RPC 2.0 MCP server, 4 tools, CLI filter flags, and scoring parity

* Wed Oct 07 2026 openOODA-tools <ops@openooda.org> - 0.1.0-1
- Initial sovereign release: syntax highlighting, oote palettes, and MCP stdio surface

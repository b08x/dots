<div align="center">

# dots

**Workstation configuration managed with yadm, Jinja2 multi-host templating, and a Charm Gum TUI.**

[![Managed by yadm](https://img.shields.io/badge/managed%20by-yadm-4B3A8C?style=flat-square&logo=git&logoColor=white)](https://yadm.io/)
[![Shell: Bash / Zsh](https://img.shields.io/badge/shell-bash%20%7C%20zsh-7B4FE0?style=flat-square&logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Tests: Bats](https://img.shields.io/badge/tests-bats--core-D2601A?style=flat-square&logo=linux&logoColor=white)](https://github.com/bats-core/bats-core)
[![License: Unlicensed](https://img.shields.io/badge/license-unlicensed-lightgrey?style=flat-square)](#license)

</div>

---

yadm has a few benefits over other dotfile managers. Unless alternate files are being used, files managed by yadm aren't symlinked. It treats the entire home directory as a bare git repository that you can commit to.

The bootstrap feature makes it relatively simple to perform other system restore tasks upon initialization or reinstall. For example, after a clone and checkout [this bootstrap][b0e2c0a9] runs which installs some necessary tools, imports guake settings, and ensures the keybinding daemon is enabled and started.

  [b0e2c0a9]: https://github.com/b08x/dots/blob/main/.config/yadm/bootstrap.d/01-system.sh "bootstrap"


Alternate files and templates make it possible to manage multiple hosts from a single repo. If you have two hosts that use the same config but require different settings, you can create a template to accommodate. yadm also uses jinja2 templating which complements Ansible system file templates. Here for example is a snippet from [.config/i3/config##template][0177e00c] that specifies the tray_output parameter in the resulting `.config/i3/config`

  [9b953518]: https://yadm.io/docs/alternates "Symlink alternates"
  [043c86e3]: https://yadm.io/docs/templates "Template"
  [0177e00c]: https://github.com/b08x/dots/blob/main/.config/i3/config%23%23template "i3 config"


```yaml
{% if yadm.hostname == "soundbot" %}
        tray_output HDMI1
{% endif %}

{% if yadm.hostname == "ninjabot" %}
        tray_output HDMI-2
{% endif %}
```

Check out the author's impressive [documentation](https://yadm.io/docs/overview)

---

## Contributing

This is a personal configuration repository tailored to specific hardware architectures and operational preferences. Issues and pull requests are welcome for generic bug fixes or portability improvements in the bootstrap orchestrator and test suite.

## License

Personal configuration. All rights reserved. Intended for private reference and reproduction.

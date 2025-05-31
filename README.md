# dots

1. yadm clone <https://github.com/b08x/dots>
2. run bootstrap

### Update the yadm repo origin URL

```shell
#!/bin/sh

echo "Updating the yadm repo origin URL"
yadm remote set-url origin "git@github.com:MyUser/dotfiles.git"
```


```bash
echo '.ssh/id_rsa' > ~/.config/yadm/encrypt
yadm encrypt
```


# Later, decrypt your ssh key

```bash
yadm decrypt
```

```bash
curl -sSL https://bit.ly/b08x-dots | bash
```

# TODO

- [ ] integrate into [ansible collection](https://github.com/syncopatedX/ansible)

## Maybe

- [ ] integrate as option into [iso](https://github.com/syncopatedX/iso)

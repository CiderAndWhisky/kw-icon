# KW Icon

KW Icon is a tiny macOS menu bar app that can show either the current ISO
calendar week as `KW 23` or the current sprint and ISO calendar week as
`SP24-KW23` in the menu bar.

- `KW` is the current ISO calendar week.
- `SP` switches on Wednesday at 12:00 in `Europe/Madrid` and follows the week
  in which the sprint ends.
- In the `KW` view, choose between the ISO week and sprint number from the menu.

![image.png](assets/screenshot.png)

After launching the app, hold Command and drag the label to the position you
prefer.

## Build

```sh
./scripts/build.sh
```

The app bundle is created at:

```text
dist/KW Icon.app
```

Run it without installing:

```sh
open "dist/KW Icon.app"
```

## Install

Install to `~/Applications` and launch:

```sh
./scripts/install.sh
```

Install and start automatically at login:

```sh
./scripts/install.sh --login
```

Uninstall the login item:

```sh
./scripts/install.sh --uninstall-login
```

Then delete `~/Applications/KW Icon.app` if you no longer want the app.

## Releases

Check https://github.com/CiderAndWhisky/kw-icon/releases/ for new releases

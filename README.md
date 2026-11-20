# modern-openpanel-theme

Modern is a redesigned theme for the OpenPanel 2.x user panel: a dark sidebar, the `op-` component kit (cards, tool tiles, chips, segmented switches), a dashboard with **Overview** and **Tools** views, and a guided installer for apps.

![Screenshot](screenshot.png)

## Install

```bash
git clone https://github.com/stefanpejcic/modern-openpanel-theme /etc/openpanel/openpanel/templates/modern
opencli config update template modern
```

The command restarts the panel so the theme loads right away. You can also pick **Modern** in **OpenAdmin > Settings > OpenPanel > Theme**.

## What's inside

The theme only holds the files it changes, every other page comes from the panel's built-in templates, so those keep following panel updates.

- `base.html`, `partials/`, and the page folders (`dashboard/`, `domains/`, `emails/`, `files/`, `manager/`, ...): the redesigned pages.
- `partials/_op_icons.html`: the icon set the pages use.
- `static/css/op.css`, `static/js/op-kit.js`: the component kit.
- `static/js/install-wizard.js`, `static/js/conf-editor.js`: the app installer and the config editor.
- `static/images/apps/`: app logos for the installer.
- `static/vendor/fonts/inter/`: Inter (SIL Open Font License).

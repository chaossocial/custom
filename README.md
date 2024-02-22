# chaos.social customisations

chaos.social isn't running entirely vanilla Mastodon. This repository should cover most of our customisations:

- ``favicon`` contains our fancy fairydust-based favicon (thank you, @blinry!)
- ``images`` contain all our variations of the Mastodon shown in the lower left-hand corner of the page, most notably
  the default version carrying a fairydust (rocket), and a lot of versions with various pride flags. You can also find
  larger / SVG versions of our favicon there.
- ``pages`` contains the page we show during extended maintenance. It's a standalone HTML page to be served via any web
  server.
- ``patches`` contains any patches we apply to Mastodon on every update. We try not to apply patches to Mastodon –
  currently it's just a UI limitation on how many invites can be created at once.
- ``scripts`` contain various useful scripts for managing the administration side of chaos.social (scripts for the
  moderation side can be found in the `bin` directory of our [meta.chaos.social](https://github.com/chaossocial/meta)).
  The ``scripts/install`` script is used to deploy the contents of this repo to the chaos.social server.
  The ``scripts/registration-limit.sh`` script was used when we limited the amount of new users per day; as Mastodon has
  no way of bulk-disabling invites (and invites are valid despite any sign-up limits), this script checks the daily
  sign-up limit and disables invites if the limit is reached, enabling them again the next day.
- ``themes`` contains our custom themes (``custom`` and ``custom-wide``). It also contains changes we make to the
  default themes, mostly working around the new purple theme colour (we prefer the old blue one).

## License

So far as the contents of this repository are ours to license (and not just remixes of prior art), we release them under
the [Creative Commons 4.0 BY-NC-SA](https://creativecommons.org/licenses/by-nc-sa/4.0/) license.

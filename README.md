# Nominator

A weighted random "nominator". Each **host** has its own set of **players**. Mark who's
present (they move to *The Table*), then hit **Nominate** to pick a present player at
random — weighted by ticket count. Winning spends tickets; regulars who keep losing
accrue more, so picks even out over time.

## Stack

- **Ruby on Rails 8** with **Hotwire/Turbo**
- **SQLite** database
- **Tailwind CSS + DaisyUI** via CDN (no asset build step)

## Hosts & access

There are no accounts. Visiting `/` mints a new host and redirects to
`/hosts/<uuid>`. **Possessing that UUID is the authentication** — anyone with the URL
controls that host as admin. Roles flow through `ApplicationController#current_role`
(returns `:admin` today), leaving a seam for a future second role (e.g. a read-only
spectator token).

## Data model

- `Host` — `uuid` (auto-generated, used in the URL), `nominated_player_id` (the current
  pick, or nil). `has_many :players`.
- `Player` — `belongs_to :host`; `name`, `tickets`, `present`.

## Running it

```sh
bin/rails db:prepare   # first time
bin/rails server       # http://localhost:3000
```

Visit http://localhost:3000 and you'll be redirected to a fresh host URL — bookmark it.
